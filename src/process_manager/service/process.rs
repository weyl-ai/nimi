use eyre::{Error, Result, eyre};
use serde::{Deserialize, Deserializer, Serialize};

#[derive(Debug, Serialize, Deserialize)]
/// Service process configuration
pub struct Process {
    /// Argv used to run the service
    pub argv: ArgV,
}

#[derive(Debug, Serialize)]
pub struct ArgV(Vec<String>);

impl ArgV {
    pub fn binary(&self) -> &str {
        &self.0[0]
    }

    pub fn args(&self) -> &[String] {
        &self.0[1..]
    }
}

impl TryFrom<Vec<String>> for ArgV {
    type Error = Error;

    fn try_from(value: Vec<String>) -> Result<Self> {
        if value.is_empty() {
            return Err(eyre!(
                "You must give at least one argument to `process.argv` to run a service. Got: {:?}",
                value
            ));
        }

        Ok(Self(value))
    }
}

impl<'de> Deserialize<'de> for ArgV {
    fn deserialize<D>(deserializer: D) -> std::result::Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let v = Vec::<String>::deserialize(deserializer)?;
        ArgV::try_from(v).map_err(serde::de::Error::custom)
    }
}
