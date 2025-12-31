//! Service Manager Loggers
//!
//! Reads the logs from the sub processes and prints them from the `Nimi` instance

use std::{path::PathBuf, sync::Arc};

use eyre::{Context, ContextCompat, Result};
use log::{debug, error};
use tokio::{
    fs::File,
    io::{AsyncBufReadExt, AsyncRead, AsyncWriteExt, BufReader, BufWriter, Lines},
};

/// Logger type
///
/// Formats the logs differently based on if they are intended for stdout or stderr
pub enum Logger {
    /// Regular process logs
    Stdout,

    /// Process error logs
    Stderr,
}

impl Logger {
    /// Start a logger for a given file descriptor
    pub fn start<D>(
        self,
        fd: &mut Option<D>,
        target: Arc<String>,
        logs_dir: Arc<Option<PathBuf>>,
    ) -> Result<()>
    where
        D: AsyncRead + Unpin + Send + 'static,
    {
        let mut reader = Self::get_lines_reader(fd)
            .wrap_err("Failed to acquire lines reader for stdout logger")?;

        tokio::spawn(async move {
            let mut logs_file = Self::create_logs_file(logs_dir, &target).await?;

            loop {
                match reader.next_line().await {
                    Ok(Some(line)) => {
                        self.log_line(&target, &line);
                        Self::write_log_file_line(&mut logs_file, &line).await?;
                    }
                    Ok(None) => break,
                    Err(e) => {
                        error!(target: &target, "{}", e);
                        Self::write_log_file_line(&mut logs_file, e.to_string().as_str()).await?;
                        break;
                    }
                }
            }

            Ok::<_, eyre::Report>(())
        });

        Ok(())
    }

    async fn create_logs_file(
        logs_dir: Arc<Option<PathBuf>>,
        target: &Arc<String>,
    ) -> Result<Option<BufWriter<File>>> {
        let Some(ref logs_dir) = *logs_dir else {
            return Ok(None);
        };

        let logs_path = logs_dir.join(format!("{}.txt", &target));

        let file = File::create_new(logs_path)
            .await
            .wrap_err_with(|| format!("Failed to create logs file for {}", &target))?;

        Ok(Some(BufWriter::new(file)))
    }

    async fn write_log_file_line(writer: &mut Option<BufWriter<File>>, line: &str) -> Result<()> {
        let Some(writer) = writer else {
            return Ok(());
        };

        writer.write_all(line.as_bytes()).await?;
        writer.write_all(b"\n").await?;

        Ok(())
    }

    fn log_line(&self, target: &str, line: &str) {
        match self {
            Self::Stdout => debug!(target: target, "{}", line),
            Self::Stderr => error!(target: target, "{}", line),
        }
    }

    fn get_lines_reader<D>(fd: &mut Option<D>) -> Result<Lines<BufReader<D>>>
    where
        D: AsyncRead,
    {
        let taken = fd.take().wrap_err("Service was missing field value")?;

        Ok(BufReader::new(taken).lines())
    }
}
