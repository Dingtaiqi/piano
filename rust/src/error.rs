use thiserror::Error;

#[derive(Error, Debug)]
pub enum AppError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Serial port error: {0}")]
    Serial(#[from] serialport::Error),

    #[error("Audio decode error: {0}")]
    Decode(String),

    #[error("Resample error: {0}")]
    Resample(String),

    #[error("FFI error: {0}")]
    Ffi(String),
}

pub type Result<T> = std::result::Result<T, AppError>;
