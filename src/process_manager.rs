//! Process Manager implementation for `Nimi`
//!
//! Can take a rust represntation of some `NixOS` modular services
//! and runs them streaming logs back to the original console.

use console::style;
use eyre::{Context, Result};
use std::{collections::HashMap, fmt::Display};
use tokio::sync::broadcast;

mod service;

pub use service::Service;

const ANSI_ORANGE: u8 = 208;

/// Process Manager Struct
///
/// Responsible for starting the services and streaming their outputs to the console
pub struct ProcessManager {
    services: HashMap<String, Service>,
}

impl ProcessManager {
    /// Create a new process manager instance
    pub fn new(services: HashMap<String, Service>) -> Self {
        Self { services }
    }

    fn print_manager_message(msg: impl Display) {
        let title = style("<nimi>").color256(ANSI_ORANGE);

        println!("{} {}", title, msg)
    }

    /// Run the services defined for the process manager instance
    ///
    /// Terminates on `Ctrl-C`
    pub async fn run(self) -> Result<()> {
        Self::print_manager_message("Starting services...");
        let (shutdown_tx, _) = broadcast::channel::<()>(1);

        let handles: Vec<_> = self
            .services
            .into_iter()
            .map(|(name, service)| {
                let shutdown_rx = shutdown_tx.subscribe();
                tokio::spawn(async move { service.run(&name, 24, shutdown_rx).await })
            })
            .collect();

        tokio::signal::ctrl_c()
            .await
            .wrap_err("Failed to listen for shutdown event")?;
        Self::print_manager_message("Shutting down...");

        let _ = shutdown_tx.send(());

        for handle in handles {
            let _ = handle.await;
        }

        Self::print_manager_message("Finished shutdown");

        Ok(())
    }
}
