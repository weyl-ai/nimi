use std::collections::HashMap;

mod config_data;

pub use config_data::ConfigData;

pub struct Service {
    config_data: HashMap<String, ConfigData>,
    argv: Vec<String>,
}
