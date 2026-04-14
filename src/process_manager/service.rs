//! Module for data representation of the service
//!
//! Singly handles (de)serialization of the service data to/from the nix type

use serde::{Deserialize, Serialize};

mod config_data;
mod process;

pub use config_data::{ConfigData, ConfigDataMap};
pub use process::{ArgV, Process};

/// Service Data Struct
///
/// Rust based mirror of the services as defined in the [NixOS Modular Services
/// Modules](https://github.com/NixOS/nixpkgs/blob/a338deb8a1d11ead60c3d20b03f466b745514c38/lib/services/service.nix).
#[derive(Debug, Serialize, Deserialize)]
pub struct Service {
    /// Configuration files for the service
    #[serde(rename = "configData")]
    pub config_data: ConfigDataMap,

    /// Process configuration
    pub process: Process,
}
