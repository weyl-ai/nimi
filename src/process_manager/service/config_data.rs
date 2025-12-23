use std::path::PathBuf;

pub struct ConfigData {
    pub enabled: bool,
    pub name: String,
    pub path: PathBuf,
    pub text: Option<String>,
    pub source: PathBuf,
}
