use crate::error::{AppError, Result};
use std::io::{BufReader, Read};
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::sync::Mutex;

/// FFmpeg 可执行文件目录 (由 Dart 侧通过 FFI 设置)
static FFMPEG_DIR: Mutex<Option<PathBuf>> = Mutex::new(None);

pub fn set_ffmpeg_dir(dir: String) {
    let mut guard = FFMPEG_DIR.lock().unwrap();
    *guard = Some(PathBuf::from(dir));
}

/// 获取 ffmpeg 可执行文件路径
fn ffmpeg_path() -> PathBuf {
    let name = if cfg!(target_os = "windows") { "ffmpeg.exe" } else { "ffmpeg" };
    if let Some(ref dir) = *FFMPEG_DIR.lock().unwrap() {
        dir.join(name)
    } else {
        PathBuf::from(name)
    }
}

/// 获取空设备路径 (用于丢弃音频输出)
fn null_device() -> &'static str {
    if cfg!(target_os = "windows") { "NUL" } else { "/dev/null" }
}

#[repr(C)]
pub struct DecoderInfo {
    pub sample_rate: u32,
    pub total_samples: u64,
    pub duration_ms: u64,
    pub channels: u8,
}

pub struct AudioDecoder {
    child: Child,
    reader: BufReader<Box<dyn Read + Send>>,
    pub info: DecoderInfo,
    pub samples_read: u64,
}

impl AudioDecoder {
    pub fn open<P: AsRef<Path>>(path: P, target_rate: u32) -> Result<Self> {
        let path_str = path.as_ref().to_string_lossy().to_string();
        let info = get_audio_info(&path_str)?;

        let mut child = Command::new(ffmpeg_path())
            .args([
                "-i", &path_str,
                "-f", "u8",
                "-acodec", "pcm_u8",
                "-ar", &target_rate.to_string(),
                "-ac", "1",
                "-loglevel", "quiet",
                "pipe:1",
            ])
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .map_err(|e| AppError::Decode(format!(
                "无法启动 ffmpeg: {}", e
            )))?;

        let stdout = child.stdout.take().ok_or_else(|| {
            AppError::Decode("无法获取 ffmpeg stdout".into())
        })?;

        let reader = BufReader::with_capacity(8192, Box::new(stdout) as Box<dyn Read + Send>);

        Ok(AudioDecoder {
            child, reader,
            info: DecoderInfo {
                sample_rate: target_rate,
                total_samples: info.total_samples,
                duration_ms: info.duration_ms,
                channels: 1,
            },
            samples_read: 0,
        })
    }

    pub fn read(&mut self, buf: &mut [u8], max_samples: usize) -> Result<usize> {
        let target = max_samples.min(buf.len());
        let mut total = 0usize;
        while total < target {
            match self.reader.read(&mut buf[total..target]) {
                Ok(0) => break,
                Ok(n) => total += n,
                Err(ref e) if e.kind() == std::io::ErrorKind::Interrupted => continue,
                Err(e) => return Err(AppError::Decode(format!("FFmpeg read error: {}", e))),
            }
        }
        self.samples_read += total as u64;
        Ok(total)
    }

    pub fn close(mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

impl Drop for AudioDecoder {
    fn drop(&mut self) {
        let _ = self.child.kill();
    }
}

/// 使用 ffmpeg 获取音频元数据 (无需 ffprobe)
fn get_audio_info(path: &str) -> Result<DecoderInfo> {
    let null = null_device();
    let output = Command::new(ffmpeg_path())
        .args([
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            "-i", path,
            "-f", "null", null,
        ])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .output()
        .map_err(|e| AppError::Decode(format!(
            "无法启动 ffmpeg: {}", e
        )))?;

    if !output.status.success() {
        return Err(AppError::Decode("ffmpeg 执行失败".into()));
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let parsed: serde_json::Value = serde_json::from_str(&stdout)
        .map_err(|e| AppError::Decode(format!("JSON 解析失败: {}", e)))?;

    let streams = parsed["streams"].as_array();
    let mut sample_rate = 44100u32;
    let mut channels = 2u8;
    let mut duration_s = 0.0f64;

    if let Some(streams) = streams {
        for s in streams {
            if s["codec_type"] == "audio" {
                sample_rate = s["sample_rate"].as_str()
                    .and_then(|v| v.parse().ok())
                    .unwrap_or(sample_rate);
                channels = s["channels"].as_u64().map(|v| v as u8).unwrap_or(channels);
                break;
            }
        }
    }

    if let Some(dur_str) = parsed["format"]["duration"].as_str() {
        duration_s = dur_str.parse().unwrap_or(0.0);
    }

    let duration_ms = (duration_s * 1000.0) as u64;
    let total_samples = (duration_s * sample_rate as f64) as u64;

    Ok(DecoderInfo { sample_rate, total_samples, duration_ms, channels })
}
