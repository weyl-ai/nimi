use crate::error::Result;
use std::{collections::HashMap, process::Stdio};
use tokio::{
    io::{AsyncBufReadExt, BufReader},
    process::Command,
    sync::broadcast,
};

mod config_data;

pub use config_data::ConfigData;

#[derive(Default)]
pub struct Service {
    pub name: String,
    pub config_data: HashMap<String, ConfigData>,
    pub argv: Vec<String>,
}

impl Service {
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
                    println!("[{}] Received shutdown signal", self.name);
                    process.kill().await.ok();
                    break;
                }
                line = stdout_reader.next_line() => {
                    match line {
                        Ok(Some(line)) => println!("[{}] {}", self.name, line),
                        Ok(None) => break,
                        Err(e) => {
                            eprintln!("[{}] stdout error: {}", self.name, e);
                            break;
                        }
                    }
                }
                line = stderr_reader.next_line() => {
                    match line {
                        Ok(Some(line)) => eprintln!("[{}] ERR: {}", self.name, line),
                        Ok(None) => break,
                        Err(e) => {
                            eprintln!("[{}] stderr error: {}", self.name, e);
                            break;
                        }
                    }
                }
            }
        }

        Ok(())
    }
}
