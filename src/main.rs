use std::collections::HashMap;

use clap::{Parser, command};

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
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let manager = ProcessManager::new(vec![
        (Service {
            name: "HTTP Server".to_string(),
            argv: vec![
                "nix".to_string(),
                "run".to_string(),
                "nixpkgs#http-server".to_string(),
            ],
            ..Default::default()
        }),
        (Service {
            name: "HTTP Server 2".to_string(),
            argv: vec![
                "nix".to_string(),
                "run".to_string(),
                "nixpkgs#http-server".to_string(),
            ],
            ..Default::default()
        }),
    ]);

    manager.run().await;

    Ok(())
}
