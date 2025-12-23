use std::path::PathBuf;

pub struct ConfigData {
    enabled: bool,
    name: String,
    path: PathBuf,
    text: Option<String>,
    source: PathBuf,
}
