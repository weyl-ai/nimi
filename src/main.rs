use clap::{Parser, command};
use std::process::Stdio;
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::Command;
use tokio::sync::broadcast;

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
    let (shutdown_tx, _) = broadcast::channel::<()>(1);

    let commands = vec![
        ("tail", vec!["-f", "/var/log/syslog"]),
        ("ping", vec!["localhost"]),
        (",", vec!["http-server"]),
    ];

    let handles: Vec<_> = commands
        .into_iter()
        .map(|(cmd, args)| {
            let shutdown_rx = shutdown_tx.subscribe();
            tokio::spawn(async move { run_forever(cmd, args, shutdown_rx).await })
        })
        .collect();

    tokio::signal::ctrl_c().await?;
    println!("\nShutting down...");

    let _ = shutdown_tx.send(());

    for handle in handles {
        let _ = handle.await;
    }

    Ok(())
}

async fn run_forever(
    cmd: &str,
    args: Vec<&str>,
    mut shutdown: broadcast::Receiver<()>,
) -> Result<(), Box<dyn std::error::Error + Send>> {
    let mut child = Command::new(cmd)
        .args(&args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .kill_on_drop(true)
        .spawn()
        .unwrap();

    let stdout = child.stdout.take().unwrap();
    let stderr = child.stderr.take().unwrap();

    let mut stdout_reader = BufReader::new(stdout).lines();
    let mut stderr_reader = BufReader::new(stderr).lines();

    loop {
        tokio::select! {
            _ = shutdown.recv() => {
                println!("[{cmd}] Received shutdown signal");
                child.kill().await.ok();
                break;
            }
            line = stdout_reader.next_line() => {
                match line {
                    Ok(Some(line)) => println!("[{cmd}] {line}"),
                    Ok(None) => break, // EOF
                    Err(e) => {
                        eprintln!("[{cmd}] stdout error: {e}");
                        break;
                    }
                }
            }
            line = stderr_reader.next_line() => {
                match line {
                    Ok(Some(line)) => eprintln!("[{cmd}] ERR: {line}"),
                    Ok(None) => break,
                    Err(e) => {
                        eprintln!("[{cmd}] stderr error: {e}");
                        break;
                    }
                }
            }
        }
    }

    Ok(())
}
