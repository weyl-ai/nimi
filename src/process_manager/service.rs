use console::style;
use eyre::{Context, ContextCompat, Result, eyre};
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, env, fmt::Display, path::PathBuf, process::Stdio};
use tokio::{
    fs,
    io::{AsyncBufReadExt, BufReader},
    process::Command,
    sync::broadcast,
};

mod config_data;
mod process;

pub use config_data::ConfigData;
pub use process::Process;

/// Service Struct
///
/// Rust based mirror of the services as defined in the [NixOS Modular Services
/// Modules](https://github.com/NixOS/nixpkgs/blob/3574a048b30fdc5131af4069bd5e14980ce0a6d8/nixos/modules/system/service/portable/service.nix).
#[derive(Debug, Default, Serialize, Deserialize)]
pub struct Service {
    /// Configuration files for the service
    #[serde(rename = "configData")]
    pub config_data: HashMap<String, ConfigData>,

    /// Process configuration
    pub process: Process,
}

impl Service {
    fn print_service_message(&self, name: &str, output_color: u8, msg: impl Display) {
        let title = style(format!("<{}>", name)).color256(output_color);

        println!("{} {}", title, msg)
    }

    async fn create_config_directory(&self) -> Result<PathBuf> {
        let dir = env::temp_dir();

        for cfg in self.config_data.values() {
            let out_location = dir.join(&cfg.path);
            fs::symlink(&cfg.source, out_location)
                .await
                .wrap_err_with(|| {
                    format!("Failed to create symlink for config file: {:?}", cfg.path)
                })?;
        }

        Ok(dir)
    }

    /// Runs a service to completion, streaming it's logs to the console
    pub async fn run(
        self,
        name: &str,
        output_color: u8,
        mut shutdown_rx: broadcast::Receiver<()>,
    ) -> Result<()> {
        let config_dir = self.create_config_directory().await?;

        if self.process.argv.is_empty() {
            return Err(eyre!(
                "You must give at least one argument to `process.argv` to run a service"
            ));
        }

        let mut process = Command::new(self.process.argv[0].clone())
            .args(self.process.argv[1..].iter())
            .env_clear()
            .env("XDG_CONFIG_HOME", config_dir)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .kill_on_drop(true)
            .spawn()
            .wrap_err_with(|| {
                format!(
                    "Failed to start process. `process.argv`: {:?}",
                    self.process.argv
                )
            })?;

        let stdout = process
            .stdout
            .take()
            .wrap_err("Failed to acquire service process stdout")?;
        let stderr = process
            .stderr
            .take()
            .wrap_err("Failed to acquire service process stderr")?;

        let mut stdout_reader = BufReader::new(stdout).lines();
        let mut stderr_reader = BufReader::new(stderr).lines();

        loop {
            tokio::select! {
                _ = shutdown_rx.recv() => {
                    self.print_service_message(name, output_color, "Received shutdown signal");
                    process.kill().await.wrap_err("Failed to kill service process")?;
                    break;
                }
                line = stdout_reader.next_line() => {
                    match line {
                        Ok(Some(line)) => self.print_service_message(name, output_color, line),
                        Ok(None) => break,
                        Err(e) => {
                            self.print_service_message(name, output_color, e);
                            break;
                        }
                    }
                }
                line = stderr_reader.next_line() => {
                    match line {
                        Ok(Some(line)) => self.print_service_message(name, output_color, format!("ERR: {line}")),
                        Ok(None) => break,
                        Err(e) => {
                            self.print_service_message(name, output_color, format!("stderr error: {e}"));
                            break;
                        }
                    }
                }
            }
        }

        Ok(())
    }
}
