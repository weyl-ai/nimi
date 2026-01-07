//! Service Manager Module
//!
//! Contains items useful for spawning and managing the actual processes associated with a
//! `Service`

use std::{
    path::PathBuf,
    process::{ExitStatus, Stdio},
    sync::Arc,
};

use eyre::{Context, Result};
use log::{debug, info};
use thiserror::Error;
use tokio::time::timeout;
use tokio::{
    process::{Child, Command},
    task::JoinSet,
};

pub mod config_dir;
pub mod logger;

pub use config_dir::ConfigDir;
pub use logger::Logger;
use tokio_util::sync::CancellationToken;

use crate::process_manager::{Service, Settings, settings::RestartMode};

/// Responsible for the running of and managing of service state
pub struct ServiceManager {
    settings: Arc<Settings>,
    cancel_tok: CancellationToken,

    name: Arc<String>,
    service: Service,

    current_restart_count: usize,

    config_dir: ConfigDir,
    logs_dir: Arc<Option<PathBuf>>,
}

/// Errors which can occur during service management
#[derive(Error, Debug)]
pub enum ServiceError {
    /// Error for when the process exits with a non zero exit code
    #[error("service exited with status {status}")]
    ProcessExited {
        /// Exit status
        status: ExitStatus,
    },
}

/// Used to initialize the Service Manager in a structured manner
pub struct ServiceManagerOpts {
    /// Directory to store logs in
    pub logs_dir: Arc<Option<PathBuf>>,
    /// Temporary directory
    pub tmp_dir: Arc<PathBuf>,

    /// Process manager settings
    pub settings: Arc<Settings>,

    /// Service name
    pub name: Arc<String>,

    /// Service config
    pub service: Service,

    /// Cancellation token
    pub cancel_tok: CancellationToken,
}

impl ServiceManager {
    /// Creates a new Service Manager
    ///
    /// This creates the corresponding processes and supervises the operation for a given
    /// `Service`.
    ///
    /// This also produces a `ConfigDir` instance per service.
    pub async fn new(opts: ServiceManagerOpts) -> Result<Self> {
        Ok(Self {
            config_dir: ConfigDir::new(&opts.tmp_dir, &opts.service.config_data).await?,

            settings: opts.settings,
            cancel_tok: opts.cancel_tok,

            name: opts.name,
            service: opts.service,

            current_restart_count: 0,
            logs_dir: opts.logs_dir,
        })
    }

    /// Run the `Service` managed by this `ServiceManager`
    ///
    /// This will handle restarts, attach logging processes and manage linking the config
    /// directory.
    pub async fn run(&mut self) -> Result<()> {
        while let Err(e) = self.spawn_service_process().await {
            match e.downcast_ref() {
                Some(ServiceError::ProcessExited { status }) => {
                    info!("Process {} exited with status {}", &self.name, status)
                }
                None => return Err(e),
            }

            match self.settings.restart.mode {
                RestartMode::Always => info!("restarting (mode: always)"),
                RestartMode::UpToCount => {
                    if self.current_restart_count >= self.settings.restart.count {
                        info!(
                            "Not restarting (mode: up-to-count {}/{})",
                            self.current_restart_count, self.settings.restart.count
                        );
                        break;
                    }

                    self.current_restart_count += 1;

                    info!(
                        "Restarting (mode: up-to-count {}/{})",
                        self.current_restart_count, self.settings.restart.count
                    );
                }
                RestartMode::Never => {
                    info!("Not restarting (mode: never)");

                    break;
                }
            }

            tokio::select! {
                _ = tokio::time::sleep(self.settings.restart.time) => {},
                _ = self.cancel_tok.cancelled() => {
                    info!("Received shutdown during restart delay for {}", self.name);
                    break;
                }
            }
        }

        Ok(())
    }

    /// Spawns a service process
    ///
    /// Attaches loggers and `wait`s on the process, forwarding
    /// shutdown sequeneces
    pub async fn spawn_service_process(&mut self) -> Result<()> {
        let mut process = self.create_service_child().await?;
        let mut set = JoinSet::new();

        Logger::Stdout.start(
            &mut process.stdout,
            Arc::clone(&self.name),
            Arc::clone(&self.logs_dir),
            &mut set,
        )?;
        Logger::Stderr.start(
            &mut process.stderr,
            Arc::clone(&self.name),
            Arc::clone(&self.logs_dir),
            &mut set,
        )?;

        tokio::select! {
            _ = self.cancel_tok.cancelled() => {
                debug!(target: &self.name, "Received shutdown signal");
                Self::shutdown_process(&mut process, self.settings.restart.time).await?;
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

    /// Kill a service process gracefully
    pub async fn shutdown_process(
        process: &mut Child,
        timeout_duration: std::time::Duration,
    ) -> Result<()> {
        #[cfg(unix)]
        {
            use nix::sys::signal::{Signal, kill};
            use nix::unistd::Pid;

            if let Some(pid) = process.id() {
                let pid = Pid::from_raw(pid as i32);
                let _ = kill(pid, Signal::SIGTERM);
                if timeout(timeout_duration, process.wait()).await.is_err() {
                    let _ = kill(pid, Signal::SIGKILL);
                    let _ = process.wait().await;
                }

                return Ok(());
            }
        }

        process
            .kill()
            .await
            .wrap_err("Failed to kill service process")
    }

    /// Create service child
    ///
    /// Responsible for creating the actual child process for the
    /// service
    pub async fn create_service_child(&self) -> Result<Child> {
        Command::new(self.service.process.argv.binary())
            .args(self.service.process.argv.args())
            .env_clear()
            .env("XDG_CONFIG_HOME", &self.config_dir)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .kill_on_drop(true)
            .spawn()
            .wrap_err_with(|| {
                format!(
                    "Failed to start process for service: {:?}",
                    self.service.process
                )
            })
    }
}
