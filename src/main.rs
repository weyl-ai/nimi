use std::collections::HashMap;

use clap::{Parser, command};

pub use crate::error::{Error, Result};
use crate::process_manager::{ProcessManager, Service};

pub mod error;
pub mod process_manager;

/// NixOS modular services runner and container init
///
/// # Examples
///
/// ```bash
/// nimi nixpkgs#ghostunnel .#my-pkg-with-service
/// ```
#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    /// Flake references to packages with `passthru.services` defined
    services: Vec<String>,
}

#[tokio::main]
async fn main() -> Result<()> {
    let manager = ProcessManager::new(vec![
        Service::new(
            "HTTP Server".to_string(),
            vec![
                "nix".to_string(),
                "run".to_string(),
                "nixpkgs#http-server".to_string(),
            ],
            Default::default(),
        ),
        Service::new(
            "HTTP Server 2".to_string(),
            vec![
                "nix".to_string(),
                "run".to_string(),
                "nixpkgs#http-server".to_string(),
            ],
            Default::default(),
        ),
    ]);

    manager.run().await
}
