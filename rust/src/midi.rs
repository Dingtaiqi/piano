use crate::error::{AppError, Result};
use midly::{Smf, TrackEventKind, MetaMessage};
use std::fs;

/// MIDI 解析结果，通过 FFI 返回
#[repr(C)]
pub struct MidiResult {
    pub notes: *mut u8,     // note 数组 (calloc 分配, Dart 释放)
    pub note_count: u32,
    pub name: [u8; 64],     // 文件名 (UTF-8)
}

/// 解析 MIDI 文件，返回 note 数组 (索引 1-12)
pub fn parse_midi(path: &str) -> Result<MidiResult> {
    let data = fs::read(path)?;
    let smf = Smf::parse(&data).map_err(|e| AppError::Decode(format!("MIDI parse: {}", e)))?;

    let mut notes = Vec::new();

    for track in smf.tracks {
        for event in track {
            match event.kind {
                TrackEventKind::Midi { channel: _, message } => {
                    match message {
                        midly::MidiMessage::NoteOn { key, vel } => {
                            if vel.as_int() > 0 && key.as_int() >= 21 && key.as_int() <= 108 {
                                let note = (key.as_int() % 12) as u8 + 1; // MIDI note → 1-12
                                notes.push(note);
                            }
                        }
                        _ => {}
                    }
                }
                TrackEventKind::Meta(MetaMessage::TrackName(name)) => {
                    // Could use track name, but we'll use filename
                    let _ = name;
                }
                _ => {}
            }
        }
    }

    // 构建返回结构
    let len = notes.len();
    let mut note_buf: Vec<u8> = vec![0u8; len];
    note_buf.copy_from_slice(&notes);

    // 提取文件名
    let name = std::path::Path::new(path)
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("unknown");
    let mut name_bytes = [0u8; 64];
    let name_utf8 = name.as_bytes();
    let copy_len = name_utf8.len().min(63);
    name_bytes[..copy_len].copy_from_slice(&name_utf8[..copy_len]);

    Ok(MidiResult {
        notes: note_buf.leak().as_mut_ptr(),
        note_count: len as u32,
        name: name_bytes,
    })
}
