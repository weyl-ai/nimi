use crate::error::Result;

use tokio::sync::broadcast;

mod service;

pub use service::Service;

pub struct ProcessManager {
    services: Vec<Service>,
}

impl ProcessManager {
    pub fn new(services: Vec<Service>) -> Self {
        Self { services }
    }

    pub async fn run(self) -> Result<()> {
        let (shutdown_tx, _) = broadcast::channel::<()>(1);

        let handles: Vec<_> = self
            .services
            .into_iter()
            .map(|service| {
                let shutdown_rx = shutdown_tx.subscribe();
                tokio::spawn(async move { service.run(shutdown_rx).await })
            })
            .collect();

        tokio::signal::ctrl_c().await?;
        println!("\nShutting down...");

        let _ = shutdown_tx.send(());

        for handle in handles {
            let _ = handle.await;
        }

        Ok(())
    }
}
