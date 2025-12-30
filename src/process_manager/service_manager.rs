use std::{env, path::PathBuf, process::Stdio, sync::Arc};

use eyre::{Context, ContextCompat, Result, eyre};
use log::{debug, error, info};
use sha2::{Digest, Sha256};
use tokio::{
    fs,
    io::{AsyncBufReadExt, BufReader},
    process::{Child, Command},
    sync::broadcast,
};

use crate::process_manager::{Service, Settings, settings::RestartMode};

/// Responsible for the running of and managing of service state
pub struct ServiceManager<'a> {
    settings: Arc<Settings>,
    shutdown_rx: broadcast::Receiver<()>,

    name: &'a str,
    service: Service,

    current_restart_count: usize,
}

impl<'a> ServiceManager<'a> {
    pub fn new(
        settings: Arc<Settings>,
        name: &'a str,
        service: Service,
        shutdown_rx: broadcast::Receiver<()>,
    ) -> Self {
        Self {
            settings,
            shutdown_rx,

            name,
            service,

            current_restart_count: 0,
        }
    }

    pub async fn create_config_directory(&self) -> Result<PathBuf> {
        let bytes = serde_json::to_vec(&self.service.config_data)
            .wrap_err("Failed to serialize config data files to bytes")?;
        let digest = Sha256::digest(&bytes);

        let dir_name = format!("nimi-config-{:x}", digest);
        let tmp = env::temp_dir();
        let tmp_subdir = tmp.join(&dir_name);

        if fs::try_exists(&tmp_subdir).await? {
            return Ok(tmp_subdir);
        }

        fs::create_dir(&tmp_subdir).await?;

        for cfg in self.service.config_data.values() {
            let out_location = tmp_subdir.join(&cfg.path);
            fs::symlink(&cfg.source, out_location)
                .await
                .wrap_err_with(|| {
                    format!("Failed to create symlink for config file: {:?}", cfg.path)
                })?;
        }

        Ok(tmp_subdir)
    }

    async fn create_child(&self) -> Result<Child> {
        let config_dir = self.create_config_directory().await?;

        let child = Command::new(&self.service.process.argv[0])
            .args(&self.service.process.argv[1..])
            .env_clear()
            .env("XDG_CONFIG_HOME", config_dir)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .kill_on_drop(true)
            .spawn()
            .wrap_err_with(|| {
                format!(
                    "Failed to start process for service: {:?}",
                    self.service.process
                )
            })?;

        Ok(child)
    }

    pub async fn spawn_service_process(&mut self) -> Result<()> {
        if self.service.process.argv.is_empty() {
            return Err(eyre!(
                "You must give at least one argument to `process.argv` to run a service"
            ));
        }

        let mut process = self.create_child().await?;

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
                _ = self.shutdown_rx.recv() => {
                    debug!(target: self.name, "Received shutdown signal");
                    process.kill().await.wrap_err("Failed to kill service process")?;

                    return Ok(());
                }
                line = stdout_reader.next_line() => {
                    match line {
                        Ok(Some(line)) => debug!(target: self.name, "{}", line),
                        Ok(None) => break,
                        Err(e) => {
                            error!(target: self.name, "{}", e);
                            break;
                        }
                    }
                }
                line = stderr_reader.next_line() => {
                    match line {
                        Ok(Some(line)) => error!(target: self.name, "{}", line),
                        Ok(None) => break,
                        Err(e) => {
                            error!(target: self.name, "{}", e);
                            break;
                        }
                    }
                }
            }
        }

        let status = process.wait().await?;

        if !status.success() {
            return Err(eyre!(
                "Service `{}` exited with status: {}",
                self.name,
                status
            ));
        }

        Ok(())
    }

    pub async fn run(&mut self) -> Result<()> {
        loop {
            let Err(e) = self.spawn_service_process().await else {
                return Ok(());
            };

            error!(target: self.name, "{}", e);

            match self.settings.restart.mode {
                RestartMode::Always => {
                    info!("Process {} exited, restarting (mode: always)", &self.name);
                }
                RestartMode::UpToCount => {
                    if self.current_restart_count >= self.settings.restart.count {
                        info!(
                            "Process {} exited, not restarting (mode: up-to-count {}/{})",
                            &self.name, self.current_restart_count, self.settings.restart.count
                        );
                        return Ok(());
                    }

                    self.current_restart_count += 1;

                    info!(
                        "Process {} exited, restarting (mode: up-to-count {}/{})",
                        &self.name, self.current_restart_count, self.settings.restart.count
                    );
                }
                RestartMode::Never => {
                    info!(
                        "Process {} exited, not restarting (mode: never)",
                        &self.name
                    );

                    return Ok(());
                }
            }

            tokio::select! {
                _ = tokio::time::sleep(self.settings.restart.time) => {},
                _ = self.shutdown_rx.recv() => {
                    info!("Received shutdown during restart delay for {}", self.name);
                    return Ok(());
                }
            }
        }
    }
}
