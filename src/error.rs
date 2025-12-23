use std::{io, str::Utf8Error};
use thiserror::Error;

pub type Result<T> = std::result::Result<T, Error>;

#[derive(Error, Debug)]
pub enum Error {
    #[error(
        "
IO Error Occurred: \n{0}
    "
    )]
    IOErr(#[from] io::Error),
}
