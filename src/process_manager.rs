use std::collections::HashMap;

mod service;

pub use service::Service;

pub struct ProcessManager {
    services: HashMap<String, Service>,
}
