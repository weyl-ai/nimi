//! Module for data representation of the service
//!
//! Singly handles (de)serialization of the service data to/from the nix type

use serde::{Deserialize, Serialize};

mod config_data;
mod process;

pub use config_data::ConfigDataMap;
pub use process::Process;

/// Service Data Struct
///
/// Rust based mirror of the services as defined in the [NixOS Modular Services
/// Modules](https://github.com/NixOS/nixpkgs/blob/3574a048b30fdc5131af4069bd5e14980ce0a6d8/nixos/modules/system/service/portable/service.nix).
#[derive(Debug, Serialize, Deserialize)]
pub struct Service {
    /// Configuration files for the service
    #[serde(rename = "configData")]
    pub config_data: ConfigDataMap,

    /// Process configuration
    pub process: Process,
}
