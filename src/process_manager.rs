//! Process Manager implementation for `Nimi`
//!
//! Can take a rust represntation of some `NixOS` modular services
//! and runs them streaming logs back to the original console.

use eyre::{Context, Result};
use log::{debug, error, info};
use std::{collections::HashMap, env, sync::Arc};
use tokio::{process::Command, sync::broadcast};

pub mod service;
pub mod service_manager;
pub mod settings;

pub use service::Service;
pub use service_manager::ServiceManager;
pub use settings::Settings;

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

        Ok(())
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

        let (shutdown_tx, _) = broadcast::channel::<()>(1);

        let settings = Arc::new(self.settings);
        let tmp_dir = Arc::new(env::temp_dir());

        let mut join_set = tokio::task::JoinSet::new();

        for (name, service) in self.services {
            let shutdown_rx = shutdown_tx.subscribe();
            let settings = Arc::clone(&settings);
            let tmp_dir = Arc::clone(&tmp_dir);

            join_set.spawn(async move {
                ServiceManager::new(tmp_dir, settings, &name, service, shutdown_rx)
                    .await?
                    .run()
                    .await
            });
        }

        let shutdown_signal = tokio::signal::ctrl_c();
        tokio::pin!(shutdown_signal);

        loop {
            tokio::select! {
                shutdown = &mut shutdown_signal => {
                    shutdown.wrap_err("Failed to listen for shutdown event")?;
                    info!("Shutting down...");
                    let _ = shutdown_tx.send(());
                    break;
                }
                result = join_set.join_next() => {
                    match result {
                        Some(Ok(Ok(()))) => {
                            if join_set.is_empty() {
                                return Ok(());
                            }
                        }
                        Some(Ok(Err(err))) => {
                            info!("Shutting down...");
                            let _ = shutdown_tx.send(());
                            while join_set.join_next().await.is_some() {}
                            return Err(err).wrap_err("Process failed");
                        }
                        Some(Err(err)) => {
                            info!("Shutting down...");
                            let _ = shutdown_tx.send(());
                            while join_set.join_next().await.is_some() {}
                            return Err(err).wrap_err("Process task panicked");
                        }
                        None => return Ok(()),
                    }
                }
            }
        }

        while join_set.join_next().await.is_some() {}

        info!("Finished shutdown");

        Ok(())
    }
}
