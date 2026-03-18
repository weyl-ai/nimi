//! mprocs TUI frontend for nimi services
//!
//! Reads a nimi JSON config, pre-creates config directories,
//! converts nimi services to mprocs processes, and launches
//! the mprocs interactive TUI.

use std::path::PathBuf;

use clap::Parser;
use eyre::{Context, Result};

use nimi::cli::Cli;
use nimi::tui::{config_dirs::create_config_dirs, convert::convert_config};

/// mprocs TUI frontend for nimi services
#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct TuiCli {
    /// Path to the JSON nimi config file
    #[arg(short, long)]
    config: PathBuf,
}

#[tokio::main]
async fn main() -> Result<()> {
    color_eyre::install().wrap_err("Failed to setup color_eyre")?;

    let cli = TuiCli::parse();

    let config = Cli::read_config(&cli.config)
        .await
        .wrap_err_with(|| format!("Failed to read config file {:?}", cli.config))?;

    if let Some(startup_cmd) = &config.settings.startup.run_on_startup {
        let status = tokio::process::Command::new(startup_cmd)
            .status()
            .await
            .wrap_err_with(|| format!("Failed to run startup command: {:?}", startup_cmd))?;
        if !status.success() {
            eyre::bail!("Startup command failed with status: {}", status);
        }
    }

    let config_dirs = create_config_dirs(&config)
        .await
        .wrap_err("Failed to create config directories")?;

    let (procs, mprocs_settings) = convert_config(&config, &config_dirs);

    lib::run_with_config(procs, mprocs_settings)
        .await
        .map_err(|e| eyre::eyre!("{:#}", e))
        .wrap_err("mprocs TUI failed")
}
