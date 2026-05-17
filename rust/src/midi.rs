use crate::error::{AppError, Result};
use midly::{Smf, TrackEventKind};
use std::fs;

#[repr(C)]
pub struct MidiResult {
    pub notes: *mut u8,
    pub note_count: u32,
    pub name: [u8; 64],
}

/// 解析 MIDI，自动选择音符最多的轨道（主旋律）
pub fn parse_midi(path: &str) -> Result<MidiResult> {
    let data = fs::read(path)?;
    let smf = Smf::parse(&data).map_err(|e| AppError::Decode(format!("MIDI parse: {}", e)))?;

    // 每根轨道单独收集音符
    let mut track_notes: Vec<Vec<u8>> = Vec::new();

    for track in &smf.tracks {
        let mut notes = Vec::new();
        for event in track {
            if let TrackEventKind::Midi { channel: _, message } = event.kind {
                if let midly::MidiMessage::NoteOn { key, vel } = message {
                    if vel.as_int() > 0 && key.as_int() >= 21 && key.as_int() <= 108 {
                        notes.push((key.as_int() % 12) as u8 + 1);
                    }
                }
            }
        }
        if !notes.is_empty() {
            track_notes.push(notes);
        }
    }

    // 选音符最多的轨道
    let best = track_notes
        .iter()
        .max_by_key(|n| n.len())
        .ok_or_else(|| AppError::Decode("No notes found".into()))?;

    let len = best.len();
    let mut note_buf = vec![0u8; len];
    note_buf.copy_from_slice(best);

    let name = std::path::Path::new(path)
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("unknown");
    let mut name_bytes = [0u8; 64];
    let copy_len = name.as_bytes().len().min(63);
    name_bytes[..copy_len].copy_from_slice(&name.as_bytes()[..copy_len]);

    Ok(MidiResult {
        notes: note_buf.leak().as_mut_ptr(),
        note_count: len as u32,
        name: name_bytes,
    })
}
