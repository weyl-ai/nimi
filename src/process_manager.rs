//! Process Manager implementation for `Nimi`
//!
//! Can take a rust represntation of some `NixOS` modular services
//! and runs them streaming logs back to the original console.

use eyre::{Context, Result, eyre};
use futures::future::OptionFuture;
use log::{debug, error, info};
use std::{collections::HashMap, env, io::ErrorKind, path::PathBuf, sync::Arc};
use tokio::signal::unix::{SignalKind, signal};
use tokio::{fs, process::Command, task::JoinSet};
use tokio_util::sync::CancellationToken;

pub mod service;
pub mod service_manager;
pub mod settings;

pub use service::Service;
pub use service_manager::ServiceManager;
pub use settings::Settings;

use crate::process_manager::service_manager::ServiceManagerOpts;

/// Process Manager Struct
///
/// Responsible for starting the services and streaming their outputs to the console
pub struct ProcessManager {
    services: HashMap<String, Service>,
    settings: Settings,
}

impl ProcessManager {
    /// Create a new process manager instance
    pub fn new(services: HashMap<String, Service>, settings: Settings) -> Self {
        Self { services, settings }
    }

    async fn run_startup_process(bin: &str) -> Result<()> {
        let output = Command::new(bin)
            .env_clear()
            .kill_on_drop(true)
            .output()
            .await
            .wrap_err_with(|| format!("Failed to run startup binary: {:?}", bin))?;

        debug!(target: bin, "{}", str::from_utf8(&output.stdout)?);
        let stderr = str::from_utf8(&output.stderr)?;
        if !stderr.is_empty() {
            error!(target: bin, "{}", stderr);
        }

        if !output.status.success() {
            return Err(eyre!(
                "Startup process exited with non-zero exit code: {}",
                output.status
            ));
        }

        Ok(())
    }

    /// Create logs dir
    ///
    /// Creates the logs directory for the process manager
    /// to have it's services create textual log files in
    pub async fn create_logs_dir(logs_path: &str) -> Result<PathBuf> {
        let cwd = env::current_dir()?;

        let target = cwd.join(logs_path);

        let mut logs_no = 0;
        loop {
            let sub_dir = target.join(format!("logs-{logs_no}"));
            logs_no += 1;

            match fs::create_dir_all(&sub_dir).await {
                Ok(()) => return Ok(sub_dir),
                Err(e) if e.kind() == ErrorKind::AlreadyExists => continue,
                Err(e) => {
                    return Err(e).wrap_err_with(|| {
                        format!("Failed to create logs dir: {}", sub_dir.to_string_lossy())
                    });
                }
            };
        }
    }

    /// Spawn Child Processes
    ///
    /// Spawns every service this process manager manages into a `JoinSet`
    pub async fn spawn_child_processes(
        self,
        cancel_tok: &CancellationToken,
    ) -> Result<JoinSet<Result<()>>> {
        let mut join_set = tokio::task::JoinSet::new();

        let settings = Arc::new(self.settings);
        let logs_dir = Arc::new(
            OptionFuture::from(
                settings
                    .logging
                    .logs_dir
                    .as_deref()
                    .map(Self::create_logs_dir),
            )
            .await
            .transpose()?,
        );
        let tmp_dir = Arc::new(env::temp_dir());

        for (name, service) in self.services {
            let opts = ServiceManagerOpts {
                logs_dir: Arc::clone(&logs_dir),
                tmp_dir: Arc::clone(&tmp_dir),

                settings: Arc::clone(&settings),

                name: Arc::new(name),
                service,
                cancel_tok: cancel_tok.clone(),
            };

            join_set.spawn(async move { ServiceManager::new(opts).await?.run().await });
        }

        Ok(join_set)
    }

    fn spawn_shutdown_task(&self, cancel_tok: &CancellationToken) {
        let token = cancel_tok.clone();
        tokio::spawn(async move {
            let mut sigterm =
                signal(SignalKind::terminate()).wrap_err("Failed to register SIGTERM handler")?;
            tokio::select! {
                _ = tokio::signal::ctrl_c() => {},
                _ = sigterm.recv() => {},
            }
            token.cancel();
            Ok::<_, eyre::Report>(())
        });
    }

    /// Run the services defined for the process manager instance
    ///
    /// Terminates on `Ctrl-C`
    pub async fn run(self) -> Result<()> {
        info!("Starting process manager...");

        if let Some(startup) = &self.settings.startup.run_on_startup {
            info!("Running startup binary...");
            Self::run_startup_process(startup).await?;
        }

        let cancel_tok = CancellationToken::new();
        self.spawn_shutdown_task(&cancel_tok);

        let mut services_set = self.spawn_child_processes(&cancel_tok).await?;

        while let Some(res) = services_set.join_next().await {
            let flat: Result<()> = res.map_err(Into::into).and_then(std::convert::identity);

            if let Err(e) = flat {
                cancel_tok.cancel();
                return Err(e);
            }
        }

        info!("Shutting down process manager...");

        Ok(())
    }
}
