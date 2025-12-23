//! Error messages for `nimi`

use std::io;
use thiserror::Error;

/// Nimi specfic `Result` alias with the custom `Error` type
pub type Result<T> = std::result::Result<T, Error>;

/// Nimi specfic `Error` type
#[derive(Error, Debug)]
#[allow(missing_docs)]
pub enum Error {
    #[error(
        "
IO Error Occurred: \n{0}
    "
    )]
    IOErr(#[from] io::Error),
}
