use crate::error::Result;

use console::style;
use rand::Rng;
use std::{collections::HashMap, fmt::Display, process::Stdio};
use tokio::{
    io::{AsyncBufReadExt, BufReader},
    process::Command,
    sync::broadcast,
};

mod config_data;

pub use config_data::ConfigData;

#[derive(Default)]
pub struct Service {
    name: String,
    config_data: HashMap<String, ConfigData>,
    argv: Vec<String>,

    output_color: u8,
}

impl Service {
    pub fn new(name: String, argv: Vec<String>, config_data: HashMap<String, ConfigData>) -> Self {
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

    pub async fn run(self, mut shutdown_rx: broadcast::Receiver<()>) -> Result<()> {
        let mut process = Command::new(self.argv[0].clone())
            .args(self.argv[1..].iter())
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
