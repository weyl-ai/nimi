//! Subreaper support for reaping orphaned grandchildren.

use eyre::{Context, Result};
#[cfg(target_os = "linux")]
use log::{debug, warn};

#[cfg(target_os = "linux")]
use std::collections::HashSet;
#[cfg(target_os = "linux")]
use std::sync::{Mutex, OnceLock};
#[cfg(target_os = "linux")]
use tokio::signal::unix::{SignalKind, signal};

#[cfg(target_os = "linux")]
use nix::sys::wait::{WaitPidFlag, WaitStatus, waitpid};
#[cfg(target_os = "linux")]
use nix::unistd::Pid;

/// Subreaper configuration and setup.
pub struct Subreaper;

impl Subreaper {
    /// Enable subreaper mode when supported.
    pub fn enable() -> Result<()> {
        #[cfg(target_os = "linux")]
        {
            let rc = unsafe { libc::prctl(libc::PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0) };
            if rc != 0 {
                return Err(std::io::Error::last_os_error())
                    .wrap_err("Failed to enable child subreaper");
            }
            Self::spawn_reaper_task().wrap_err("Failed to spawn subreaper task")?;
        }

        Ok(())
    }

    /// Track a direct child process so the reaper doesn't steal its exit status.
    pub fn track_child(pid: Option<u32>) -> Result<ChildGuard> {
        #[cfg(target_os = "linux")]
        {
            let Some(pid) = pid else {
                return Ok(ChildGuard::noop());
            };
            Self::register_child(pid as i32);
            Ok(ChildGuard::new(pid as i32))
        }

        #[cfg(not(target_os = "linux"))]
        {
            let _ = pid;
            Ok(ChildGuard::noop())
        }
    }
}

/// Guard to unregister tracked child PIDs when dropped.
pub struct ChildGuard(Option<i32>);

impl ChildGuard {
    fn new(pid: i32) -> Self {
        Self(Some(pid))
    }

    fn noop() -> Self {
        Self(None)
    }
}

impl Drop for ChildGuard {
    fn drop(&mut self) {
        #[cfg(target_os = "linux")]
        if let Some(pid) = self.0.take() {
            Subreaper::unregister_child(pid);
        }
    }
}

#[cfg(target_os = "linux")]
impl Subreaper {
    fn registry() -> &'static Mutex<HashSet<i32>> {
        static CHILDREN: OnceLock<Mutex<HashSet<i32>>> = OnceLock::new();
        CHILDREN.get_or_init(|| Mutex::new(HashSet::new()))
    }

    fn register_child(pid: i32) {
        if let Ok(mut guard) = Self::registry().lock() {
            guard.insert(pid);
        }
    }

    fn unregister_child(pid: i32) {
        if let Ok(mut guard) = Self::registry().lock() {
            guard.remove(&pid);
        }
    }

    fn snapshot_managed() -> HashSet<i32> {
        Self::registry()
            .lock()
            .map(|guard| guard.clone())
            .unwrap_or_default()
    }

    fn collect_children_from_proc() -> Result<HashSet<i32>> {
        let mut pids = HashSet::new();
        let task_dir =
            std::fs::read_dir("/proc/self/task").wrap_err("Failed to read /proc/self/task")?;

        for entry in task_dir {
            let entry = entry.wrap_err("Failed to read /proc/self/task entry")?;
            let children_path = entry.path().join("children");
            let Ok(contents) = std::fs::read_to_string(&children_path) else {
                continue;
            };
            for pid_str in contents.split_whitespace() {
                if let Ok(pid) = pid_str.parse::<i32>() {
                    pids.insert(pid);
                }
            }
        }

        Ok(pids)
    }

    fn reap_orphaned_children() {
        let managed = Self::snapshot_managed();
        let children = match Self::collect_children_from_proc() {
            Ok(children) => children,
            Err(err) => {
                warn!("Failed to enumerate child processes: {err}");
                return;
            }
        };

        for pid in children {
            if managed.contains(&pid) {
                continue;
            }

            loop {
                match waitpid(Pid::from_raw(pid), Some(WaitPidFlag::WNOHANG)) {
                    Ok(WaitStatus::Exited(pid, status)) => {
                        debug!("Reaped orphaned child {pid} with status {status}");
                        break;
                    }
                    Ok(WaitStatus::Signaled(pid, signal, _)) => {
                        debug!("Reaped orphaned child {pid} via signal {signal}");
                        break;
                    }
                    Ok(WaitStatus::StillAlive) | Err(nix::errno::Errno::ECHILD) => break,
                    Ok(_) => continue,
                    Err(nix::errno::Errno::EINTR) => continue,
                    Err(err) => {
                        warn!("Failed to reap child process {pid}: {err}");
                        break;
                    }
                }
            }
        }
    }

    fn spawn_reaper_task() -> Result<()> {
        let mut sigchld =
            signal(SignalKind::child()).wrap_err("Failed to register SIGCHLD handler")?;
        tokio::spawn(async move {
            loop {
                if sigchld.recv().await.is_none() {
                    break;
                }
                Self::reap_orphaned_children();
            }
        });
        Ok(())
    }
}
