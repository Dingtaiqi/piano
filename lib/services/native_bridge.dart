import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

DynamicLibrary _loadLib() {
  final exeDir = File(Platform.resolvedExecutable).parent.path;

  if (Platform.isWindows) {
    const libName = 'piano_native.dll';
    final candidates = ['$exeDir/$libName', libName, 'rust/target/release/$libName'];
    for (final path in candidates) {
      if (File(path).existsSync()) return DynamicLibrary.open(File(path).absolute.path);
    }
    return DynamicLibrary.open(libName);
  }

  if (Platform.isMacOS) {
    const libName = 'libpiano_native.dylib';
    final candidates = ['$exeDir/$libName', libName, 'rust/target/release/$libName'];
    for (final path in candidates) {
      if (File(path).existsSync()) return DynamicLibrary.open(File(path).absolute.path);
    }
    return DynamicLibrary.open(libName);
  }

  // Linux
  const libName = 'libpiano_native.so';
  final candidates = ['$exeDir/$libName', libName, 'rust/target/release/$libName'];
  for (final path in candidates) {
    if (File(path).existsSync()) return DynamicLibrary.open(File(path).absolute.path);
  }
  return DynamicLibrary.open(libName);
}

final DynamicLibrary _lib = _loadLib();

// ============================================================
// 串口 FFI 绑定
// ============================================================

typedef SerialEnumerateNative = Pointer<Utf8> Function();
typedef SerialEnumerateDart = Pointer<Utf8> Function();
final SerialEnumerateDart serialEnumerate =
    _lib.lookupFunction<SerialEnumerateNative, SerialEnumerateDart>('serial_enumerate');

typedef SerialOpenNative = Pointer<Void> Function(Pointer<Utf8>, Uint32);
typedef SerialOpenDart = Pointer<Void> Function(Pointer<Utf8>, int);
final SerialOpenDart serialOpen =
    _lib.lookupFunction<SerialOpenNative, SerialOpenDart>('serial_open');

typedef SerialWriteNative = Int32 Function(Pointer<Void>, Pointer<Uint8>, Uint32);
typedef SerialWriteDart = int Function(Pointer<Void>, Pointer<Uint8>, int);
final SerialWriteDart serialWrite =
    _lib.lookupFunction<SerialWriteNative, SerialWriteDart>('serial_write');

typedef SerialReadNative = Int32 Function(Pointer<Void>, Pointer<Uint8>, Uint32, Uint32);
typedef SerialReadDart = int Function(Pointer<Void>, Pointer<Uint8>, int, int);
final SerialReadDart serialRead =
    _lib.lookupFunction<SerialReadNative, SerialReadDart>('serial_read');

typedef SerialCloseNative = Void Function(Pointer<Void>);
typedef SerialCloseDart = void Function(Pointer<Void>);
final SerialCloseDart serialClose =
    _lib.lookupFunction<SerialCloseNative, SerialCloseDart>('serial_close');

typedef SerialFreeStringNative = Void Function(Pointer<Utf8>);
typedef SerialFreeStringDart = void Function(Pointer<Utf8>);
final SerialFreeStringDart serialFreeString =
    _lib.lookupFunction<SerialFreeStringNative, SerialFreeStringDart>('serial_free_string');

// ============================================================
// MIDI FFI
// ============================================================

final class MidiResult extends Struct {
  external Pointer<Uint8> notes;

  @Uint32()
  external int noteCount;

  @Array(64)
  external Array<Uint8> name;
}

typedef MidiParseFileNative = Pointer<MidiResult> Function(Pointer<Utf8>);
typedef MidiParseFileDart = Pointer<MidiResult> Function(Pointer<Utf8>);
final MidiParseFileDart midiParseFile =
    _lib.lookupFunction<MidiParseFileNative, MidiParseFileDart>('midi_parse_file');

typedef MidiFreeResultNative = Void Function(Pointer<MidiResult>);
typedef MidiFreeResultDart = void Function(Pointer<MidiResult>);
final MidiFreeResultDart midiFreeResult =
    _lib.lookupFunction<MidiFreeResultNative, MidiFreeResultDart>('midi_free_result');

