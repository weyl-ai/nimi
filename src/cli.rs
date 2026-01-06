//! Module containing the schema for the command line interface and methods to run it

use std::path::{Path, PathBuf};

use clap::{Parser, Subcommand, command};
use eyre::{Context, Result};
use format_serde_error::SerdeError;
use log::info;
use tokio::fs;

use crate::{config::Config, process_manager::ProcessManager};

/// NixOS modular services runner and container init
///
/// # Examples
///
/// ## Generate a pre-configured binary from nixos modular services
///
/// ```nix
/// pkgs.nimi.evalServicesConfig {
///   services."ghostunnel-plain-old" = {
///     imports = [ pkgs.ghostunnel.services.default ];
///     ghostunnel = {
///       listen = "0.0.0.0:443";
///       cert = "/root/service-cert.pem";
///       key = "/root/service-key.pem";
///       disableAuthentication = true;
///       target = "backend:80";
///       unsafeTarget = true;
///     };
///   };
///   services."ghostunnel-client-cert" = {
///     imports = [ pkgs.ghostunnel.services.default ];
///     ghostunnel = {
///       listen = "0.0.0.0:1443";
///       cert = "/root/service-cert.pem";
///       key = "/root/service-key.pem";
///       cacert = "/root/ca.pem";
///       target = "backend:80";
///       allowCN = [ "client" ];
///       unsafeTarget = true;
///     };
///   };
/// }
/// ```
///
/// ## Interact with an existing config
///
/// ```bash
/// nimi --config ./my-config.json validate
/// nimi --config ./my-config.json run
/// ```
#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
pub struct Cli {
    /// Path to the json representation of nimi services to run
    ///
    /// To generate this use the `evalServicesConfig` of the nix
    /// package for nimi
    #[arg(short, long)]
    pub config: PathBuf,

    /// The subcommand to run
    #[command(subcommand)]
    pub command: Command,
}

impl Cli {
    async fn read_config(path: &Path) -> Result<Config> {
        let config = fs::read_to_string(&path)
            .await
            .wrap_err("Failed to read config file from filesystem")?;

        serde_json::from_str(&config)
            .map_err(|err| SerdeError::new(config, err))
            .wrap_err("Failed to deserialize config file")
    }

    /// Execute the nimi CLI
    ///
    /// Read the configuration file and runs the specificed `Command`
    pub async fn run(self) -> Result<()> {
        let config = Self::read_config(&self.config)
            .await
            .wrap_err_with(|| format!("Failed to read nimi config ({:?})", self.config))?;

        match self.command {
            Command::Validate => {
                info!("Successfully validated nimi config");

                Ok(())
            }
            Command::Run => {
                info!("Launching process manager...");

                ProcessManager::new(config.services, config.settings)
                    .run()
                    .await
                    .wrap_err("Failed to run processes")?;

                info!("Process manager finished");

                Ok(())
            }
        }
    }
}

/// The nimi subcommand to run
#[derive(Subcommand, Debug)]
pub enum Command {
    /// Validate the nimi services config file
    Validate,

    /// Run nimi services based on the config file
    Run,
}
