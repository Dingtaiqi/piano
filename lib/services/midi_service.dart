import 'dart:typed_data';

/// MIDI 解析结果
class MidiMelody {
  final String name;
  final List<int> notes; // 1-12 note indices
  final int noteCount;

  const MidiMelody({required this.name, required this.notes, required this.noteCount});
}

/// 简易 MIDI parser，提取 note 序列
class MidiService {
  /// 解析 MIDI 文件，返回 note 数组 (索引 1-12)
  static MidiMelody parse(String filePath, Uint8List data) {
    final name = filePath.split('/').last.split('\\').last.replaceAll('.mid', '').replaceAll('.midi', '');
    final notes = <int>[];
    int ticksPerQuarter = 480;
    int format = 0;
    int numTracks = 1;

    int pos = 0;
    // MThd chunk
    if (pos + 14 > data.length || _readStr(data, pos, 4) != 'MThd') {
      return MidiMelody(name: name, notes: notes, noteCount: 0);
    }
    pos += 4; // "MThd"
    final headerLen = _readU32(data, pos); pos += 4;
    format = _readU16(data, pos); pos += 2;
    numTracks = _readU16(data, pos); pos += 2;
    ticksPerQuarter = _readU16(data, pos); pos += 2;
    pos += headerLen - 6; // skip remaining header

    // Find first track with note events
    for (int t = 0; t < numTracks; t++) {
      if (pos + 8 > data.length) break;
      final chunkType = _readStr(data, pos, 4); pos += 4;
      final chunkLen = _readU32(data, pos); pos += 4;
      final chunkEnd = pos + chunkLen;

      if (chunkType != 'MTrk') {
        pos = chunkEnd;
        continue;
      }

      int runningStatus = 0;
      while (pos < chunkEnd) {
        _readVarLen(data, pos); // deltaTime (ignored for simple extraction)
        pos = _readVarLenGet(data, pos).nextPos;

        int event = data[pos];
        if (event < 0x80) {
          event = runningStatus;
        } else {
          pos++;
        }
        runningStatus = event;

        final eventType = event & 0xF0;
        if (eventType == 0x90 && pos + 1 < chunkEnd) {
          // Note On
          final note = data[pos];
          final velocity = data[pos + 1];
          pos += 2;
          if (velocity > 0 && note >= 21 && note <= 108) {
            // MIDI note → 1-12 index
            final idx = (note % 12) + 1;
            notes.add(idx);
          }
        } else if (eventType == 0x80 && pos + 1 < chunkEnd) {
          // Note Off
          pos += 2;
        } else if (eventType == 0xB0 && pos + 1 < chunkEnd) {
          pos += 2;
        } else if (eventType == 0xE0 && pos + 1 < chunkEnd) {
          pos += 2;
        } else if (eventType == 0xC0 || eventType == 0xD0) {
          pos += 1;
        } else if (event == 0xFF) {
          // Meta event
          pos++; // type
          final meta = _readVarLenGet(data, pos);
          pos = meta.nextPos + meta.value;
        } else {
          pos = chunkEnd; // unknown, skip track
        }
      }

      if (notes.isNotEmpty && t == 0) break; // Use first track with notes
    }

    return MidiMelody(name: name, notes: notes, noteCount: notes.length);
  }

  static String _readStr(Uint8List d, int pos, int len) => String.fromCharCodes(d.sublist(pos, pos + len));
  static int _readU16(Uint8List d, int p) => (d[p] << 8) | d[p + 1];
  static int _readU32(Uint8List d, int p) => (d[p] << 24) | (d[p + 1] << 16) | (d[p + 2] << 8) | d[p + 3];

  static ({int value, int nextPos}) _readVarLenGet(Uint8List d, int p) {
    int v = 0;
    while (p < d.length) {
      final b = d[p++];
      v = (v << 7) | (b & 0x7F);
      if ((b & 0x80) == 0) break;
    }
    return (value: v, nextPos: p);
  }

  static int _readVarLen(Uint8List d, int p) {
    final result = _readVarLenGet(d, p);
    return result.value;
  }
}
