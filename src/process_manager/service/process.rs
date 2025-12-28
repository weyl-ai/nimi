use serde::{Deserialize, Serialize};

#[derive(Default, Debug, Serialize, Deserialize)]
pub struct Process {
    /// Argv used to run the service
    pub argv: Vec<String>,
}
