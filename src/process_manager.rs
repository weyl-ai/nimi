//! Process Manager implementation for `Nimi`
//!
//! Can take a rust represntation of some `NixOS` modular services
//! and runs them streaming logs back to the original console.

use eyre::{Context, Result};
use log::info;
use std::{collections::HashMap, sync::Arc};
use tokio::sync::{Mutex, broadcast};

mod service;
mod settings;

pub use service::Service;
pub use settings::Settings;

use crate::process_manager::settings::RestartMode;

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

    async fn run_process(
        settings: Arc<Mutex<Settings>>,
        name: &str,
        service: Service,
        mut shutdown_rx: broadcast::Receiver<()>,
    ) -> Result<()> {
        let settings = settings.lock().await;

        let mut current_count = 0;

        loop {
            service.run(name, &mut shutdown_rx).await?;

            match settings.restart.mode {
                RestartMode::Always => {
                    info!("Process {} exited, restarting (mode: always)", &name);
                }
                RestartMode::UpToCount => {
                    info!(
                        "Process {} exited, restarting (mode: up-to-count {}/{})",
                        &name, current_count, settings.restart.count
                    );

                    if current_count >= settings.restart.count {
                        return Ok(());
                    }

                    current_count += 1;
                }
                RestartMode::Never => {
                    info!("Process {} exited, not restarting (mode: never)", &name,);

                    return Ok(());
                }
            }
        }
    }

    /// Run the services defined for the process manager instance
    ///
    /// Terminates on `Ctrl-C`
    pub async fn run(self) -> Result<()> {
        info!("Starting process manager...");
        let (shutdown_tx, _) = broadcast::channel::<()>(1);

        let sub_proc_settings = Arc::new(Mutex::new(self.settings));

        let handles: Vec<_> = self
            .services
            .into_iter()
            .map(|(name, service)| {
                let shutdown_rx = shutdown_tx.subscribe();
                let sub_proc_man = Arc::clone(&sub_proc_settings);
                tokio::spawn(async move {
                    Self::run_process(sub_proc_man, &name, service, shutdown_rx).await
                })
            })
            .collect();

        tokio::signal::ctrl_c()
            .await
            .wrap_err("Failed to listen for shutdown event")?;

        info!("Shutting down...");

        let _ = shutdown_tx.send(());

        for handle in handles {
            let _ = handle.await;
        }

        info!("Finished shutdown");

        Ok(())
    }
}
