use serde_with::DurationMilliSeconds;
use std::time::Duration;

use serde::{Deserialize, Serialize};
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

/// Restart Settings Struct
///
/// Configuration for how nimi gets restarted
#[serde_as]
#[derive(Debug, Default, Serialize, Deserialize)]
pub struct Restart {
    pub mode: RestartMode,
    #[serde_as(as = "DurationMilliSeconds<u64>")]
    pub time: Duration,
    pub count: usize,
}

/// Restart Mode
///
/// Selects how the processes get restarted on failure
#[derive(Debug, Default, Serialize, Deserialize)]
pub enum RestartMode {
    #[default]
    #[serde(rename = "never")]
    Never,
    #[serde(rename = "up-to-count")]
    UpToCount,
    #[serde(rename = "always")]
    Always,
}
