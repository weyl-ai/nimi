//! Nimi Process manager settings
//!
//! Holds data about the nix configurable settings for Nimi

use serde_with::DurationMilliSeconds;
use std::time::Duration;

use serde::{Deserialize, Deserializer, Serialize};
use serde_with::serde_as;

/// Settings Struct
///
/// Process manager runtime settings for configuring things like restart behaviour
#[derive(Debug, Default, Serialize, Deserialize)]
pub struct Settings {
    /// The restart specific settings
    pub restart: Restart,

    /// The startup specific settings
    pub startup: Startup,

    /// The logging specific settings
    pub logging: Logging,
}

/// Startup Settings Struct
///
/// Configuration for how nimi gets started
#[derive(Debug, Default, Serialize, Deserialize)]
pub struct Startup {
    /// Binary to run on startup before starting services
    #[serde(rename = "runOnStartup")]
    pub run_on_startup: Option<String>,
}

/// Logging Settings Struct
///
/// Configuration for how nimi prints logs
#[derive(Debug, Default, Serialize)]
pub struct Logging {
    /// The stringified path to the logs directory to use
    ///
    /// None if logs are disabled
    pub logs_dir: Option<String>,
}

impl<'de> Deserialize<'de> for Logging {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let raw = LoggingRaw::deserialize(deserializer)?;

        Ok(Logging {
            logs_dir: raw.enable.then_some(raw.logs_dir),
        })
    }
}

/// Logging raw struct matching nix representation
///
/// Configuration for how nimi prints logs
#[derive(Debug, Default, Serialize, Deserialize)]
struct LoggingRaw {
    /// If log files should be generated for the service
    pub enable: bool,

    /// The stringified path to the logs directory to use
    #[serde(rename = "logsDir")]
    pub logs_dir: String,
}

/// Restart Settings Struct
///
/// Configuration for how nimi gets restarted
#[serde_as]
#[derive(Debug, Default, Serialize, Deserialize)]
pub struct Restart {
    /// The mode to use for restarts
    pub mode: RestartMode,

    /// The amount of time (in milliseconds) to wait before
    /// restarting the process
    #[serde_as(as = "DurationMilliSeconds<u64>")]
    pub time: Duration,

    /// The maximum amount of restarts in `RestartMode::UpToCount`
    pub count: usize,
}

/// Restart Mode
///
/// Selects how the processes get restarted on failure
#[derive(Debug, Default, Serialize, Deserialize)]
pub enum RestartMode {
    /// Don't restart, ever
    #[default]
    #[serde(rename = "never")]
    Never,

    /// Restart a given number of times
    #[serde(rename = "up-to-count")]
    UpToCount,

    /// Restart every single time
    #[serde(rename = "always")]
    Always,
}
