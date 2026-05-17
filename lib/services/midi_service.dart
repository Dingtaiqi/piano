import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'native_bridge.dart';

class MidiMelody {
  final String name;
  final List<int> notes;
  final int noteCount;

  const MidiMelody({required this.name, required this.notes, required this.noteCount});
}

class MidiService {
  static MidiMelody? parse(String filePath) {
    final pathPtr = filePath.toNativeUtf8();
    final resultPtr = midiParseFile(pathPtr);
    calloc.free(pathPtr);

    if (resultPtr == nullptr) return null;

    final result = resultPtr.ref;
    final notes = <int>[];
    for (int i = 0; i < result.noteCount; i++) {
      notes.add(result.notes[i]);
    }

    final rawName = result.name;
    final nameBuf = <int>[];
    for (int i = 0; i < 64; i++) {
      if (rawName[i] == 0) break;
      nameBuf.add(rawName[i]);
    }
    final name = String.fromCharCodes(nameBuf);

    midiFreeResult(resultPtr);
    return MidiMelody(name: name, notes: notes, noteCount: notes.length);
  }
}
