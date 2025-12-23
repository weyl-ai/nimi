use crate::error::Result;

use console::style;
use rand::Rng;
use std::{env, fmt::Display, path::PathBuf, process::Stdio};
use tokio::{
    fs,
    io::{AsyncBufReadExt, BufReader},
    process::Command,
    sync::broadcast,
};

mod config_data;

pub use config_data::ConfigData;

/// Service Struct
///
/// Rust based mirror of the services as defined in the [NixOS Modular Services
/// Modules](https://github.com/NixOS/nixpkgs/blob/3574a048b30fdc5131af4069bd5e14980ce0a6d8/nixos/modules/system/service/portable/service.nix).
#[derive(Default)]
pub struct Service {
    name: String,
    config_data: Vec<ConfigData>,
    argv: Vec<String>,

    output_color: u8,
}

impl Service {
    /// Creates a new instance of a `Service`
    pub fn new(name: String, argv: Vec<String>, config_data: Vec<ConfigData>) -> Self {
        let output_color = rand::rng().random();

        Self {
            name,
            config_data,
            argv,
            output_color,
        }
    }

    fn print_service_message(&self, msg: impl Display) {
        let title = style(format!("<{}>", self.name)).color256(self.output_color);

        println!("{} {}", title, msg)
    }

    async fn create_config_directory(&self) -> Result<PathBuf> {
        let dir = env::temp_dir();

        for cfg in &self.config_data {
            let out_location = dir.join(&cfg.path);
            fs::symlink(&cfg.source, out_location).await?;
        }

        Ok(dir)
    }

    /// Runs a service to completion, streaming it's logs to the console
    pub async fn run(self, mut shutdown_rx: broadcast::Receiver<()>) -> Result<()> {
        let config_dir = self.create_config_directory().await?;

        let mut process = Command::new(self.argv[0].clone())
            .args(self.argv[1..].iter())
            .env_clear()
            .env("XDG_CONFIG_HOME", config_dir)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .kill_on_drop(true)
            .spawn()?;

        let stdout = process
            .stdout
            .take()
            .expect("Service process should always have an stdout handle available");
        let stderr = process
            .stderr
            .take()
            .expect("Service process should always have an stdout handle available");

        let mut stdout_reader = BufReader::new(stdout).lines();
        let mut stderr_reader = BufReader::new(stderr).lines();

        loop {
            tokio::select! {
                _ = shutdown_rx.recv() => {
                    self.print_service_message("Received shutdown signal");
                    process.kill().await.ok();
                    break;
                }
                line = stdout_reader.next_line() => {
                    match line {
                        Ok(Some(line)) => self.print_service_message(line),
                        Ok(None) => break,
                        Err(e) => {
                            self.print_service_message(e);
                            break;
                        }
                    }
                }
                line = stderr_reader.next_line() => {
                    match line {
                        Ok(Some(line)) => self.print_service_message(format!("ERR: {line}")),
                        Ok(None) => break,
                        Err(e) => {
                            self.print_service_message(format!("stderr error: {e}"));
                            break;
                        }
                    }
                }
            }
        }

        Ok(())
    }
}
