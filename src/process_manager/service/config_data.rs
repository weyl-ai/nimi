use std::{collections::HashMap, path::PathBuf};

use serde::{Deserialize, Serialize};

/// Convenience type for the map of config data
pub type ConfigDataMap = HashMap<String, ConfigData>;

#[derive(Debug, Serialize, Deserialize)]
/// Service confguration data
pub struct ConfigData {
    /// If this piece of config data was enabled
    pub enable: bool,
    /// The path to the output configuration file
    pub path: PathBuf,
    /// Contents of the config data
    pub text: Option<String>,
    /// The source from the nix store of the configuration file
    pub source: PathBuf,
}
