//! Process Manager implementation for `Nimi`
//!
//! Can take a rust represntation of some `NixOS` modular services
//! and runs them streaming logs back to the original console.

use eyre::{Context, Result};
use futures::future::OptionFuture;
use log::{debug, info};
use std::process::Stdio;
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

use crate::process_manager::service_manager::{Logger, ServiceError, ServiceManagerOpts};
use crate::subreaper::Subreaper;

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

    async fn run_startup_process(&self, bin: &str, cancel_tok: &CancellationToken) -> Result<()> {
        let mut set = JoinSet::new();

        let mut process = Command::new(bin)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .kill_on_drop(true)
            .spawn()
            .wrap_err_with(|| format!("Failed to spawn startup binary: {:?}", bin))?;
        let _child_guard =
            Subreaper::track_child(process.id()).wrap_err("Failed to track startup child")?;

        let name = Arc::new("startup".to_owned());
        let logs_dir = Arc::from(None);

        Logger::Stdout.start(
            &mut process.stdout,
            Arc::clone(&name),
            Arc::clone(&logs_dir),
            &mut set,
        )?;
        Logger::Stderr.start(
            &mut process.stderr,
            Arc::clone(&name),
            Arc::clone(&logs_dir),
            &mut set,
        )?;

        tokio::select! {
            _ = cancel_tok.cancelled() => {
                debug!(target: &name, "Received shutdown signal");
                ServiceManager::shutdown_process(&mut process, self.settings.restart.time).await?;
            }
            status = process.wait() => {
                let status = status.wrap_err("Failed to get process status")?;
                eyre::ensure!(
                    status.success(),
                    ServiceError::ProcessExited { status }
                );
            }
        }

        set.join_all().await.into_iter().collect()
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

        let cancel_tok = CancellationToken::new();
        self.spawn_shutdown_task(&cancel_tok);

        if let Some(startup) = &self.settings.startup.run_on_startup {
            info!("Running startup binary ({})...", startup);
            self.run_startup_process(startup, &cancel_tok)
                .await
                .wrap_err("Failed to run startup process")?;
        }

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
