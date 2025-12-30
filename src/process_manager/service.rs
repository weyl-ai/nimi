use serde::{Deserialize, Serialize};
use std::collections::HashMap;

mod config_data;
mod process;

pub use config_data::ConfigData;
pub use process::Process;

/// Service Data Struct
///
/// Rust based mirror of the services as defined in the [NixOS Modular Services
/// Modules](https://github.com/NixOS/nixpkgs/blob/3574a048b30fdc5131af4069bd5e14980ce0a6d8/nixos/modules/system/service/portable/service.nix).
#[derive(Debug, Default, Serialize, Deserialize)]
pub struct Service {
    /// Configuration files for the service
    #[serde(rename = "configData")]
    pub config_data: HashMap<String, ConfigData>,

    /// Process configuration
    pub process: Process,
}
