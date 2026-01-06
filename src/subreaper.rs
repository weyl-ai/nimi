//! Subreaper support for reaping orphaned grandchildren.

use eyre::{Context, Result};

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
        }

        Ok(())
    }
}
