use std::path::PathBuf;

use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct ConfigData {
    pub enabled: bool,
    pub path: PathBuf,
    pub text: Option<String>,
    pub source: PathBuf,
}
