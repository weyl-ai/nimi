//! Config Directory Module
//!
//! Handles creating the configuration directory

use eyre::{Context, OptionExt, Result};
use sha2::{Digest, Sha256};
use std::{
    ffi::OsStr,
    io::ErrorKind,
    path::{Path, PathBuf},
};
use tokio::fs;

use crate::process_manager::service::ConfigDataMap;

/// Configuration directory struct
///
/// Generates a reusable per service temp dir using a hash of the
/// configuration data
pub struct ConfigDir(PathBuf);

impl ConfigDir {
    /// Create a new configuration directory
    ///
    /// Writes the configuration to disk inside the passed tempdir with
    /// the configured files
    pub async fn new(tmp_dir: &Path, config_data: &ConfigDataMap) -> Result<Self> {
        let dir_name = Self::generate_config_directory_name(config_data)
            .wrap_err("Failed to generate config directory name")?;

        let cfg_dir_path = tmp_dir.join(&dir_name);

        for cfg in config_data.values() {
            if !cfg.enable {
                continue;
            }

            let out_location = cfg_dir_path.join(&cfg.path);

            let parent_dir = out_location
                .parent()
                .ok_or_eyre("No parent directory exists for config file")?;

            match fs::create_dir_all(parent_dir).await {
                Ok(()) => {}
                Err(e) if e.kind() == ErrorKind::AlreadyExists => {}
                Err(e) => return Err(e).wrap_err("Failed to create config file parent dir"),
            }

            match fs::symlink(&cfg.source, out_location).await {
                Ok(()) => {}
                Err(e) if e.kind() == ErrorKind::AlreadyExists => {}
                Err(e) => {
                    return Err(e).wrap_err_with(|| {
                        format!("Failed to create symlink for config file: {:?}", cfg.path)
                    });
                }
            }
        }

        Ok(Self(cfg_dir_path))
    }

    /// Generate a name for the config dir by using an Sha256 hash of
    /// the contents
    pub fn generate_config_directory_name(config_data: &ConfigDataMap) -> Result<String> {
        let bytes = serde_json::to_vec(&config_data).wrap_err_with(|| {
            format!(
                "Failed to serialize config data files to bytes: {:?}",
                config_data
            )
        })?;
        let digest = Sha256::digest(&bytes);

        Ok(format!("nimi-config-{:x}", digest))
    }
}

impl AsRef<OsStr> for ConfigDir {
    fn as_ref(&self) -> &OsStr {
        self.0.as_ref()
    }
}
