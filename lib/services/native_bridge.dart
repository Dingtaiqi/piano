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
// 解码器 FFI 绑定
// ============================================================

final class DecoderInfo extends Struct {
  @Uint32()
  external int sampleRate;

  @Uint64()
  external int totalSamples;

  @Uint64()
  external int durationMs;

  @Uint8()
  external int channels;
}

typedef DecoderSetFfmpegDirNative = Int32 Function(Pointer<Utf8>);
typedef DecoderSetFfmpegDirDart = int Function(Pointer<Utf8>);
final DecoderSetFfmpegDirDart decoderSetFfmpegDir =
    _lib.lookupFunction<DecoderSetFfmpegDirNative, DecoderSetFfmpegDirDart>('decoder_set_ffmpeg_dir');

typedef DecoderOpenNative = Pointer<Void> Function(Pointer<Utf8>, Uint32);
typedef DecoderOpenDart = Pointer<Void> Function(Pointer<Utf8>, int);
final DecoderOpenDart decoderOpen =
    _lib.lookupFunction<DecoderOpenNative, DecoderOpenDart>('decoder_open');

typedef DecoderGetInfoNative = Int32 Function(Pointer<Void>, Pointer<DecoderInfo>);
typedef DecoderGetInfoDart = int Function(Pointer<Void>, Pointer<DecoderInfo>);
final DecoderGetInfoDart decoderGetInfo =
    _lib.lookupFunction<DecoderGetInfoNative, DecoderGetInfoDart>('decoder_get_info');

typedef DecoderReadNative = Int32 Function(Pointer<Void>, Pointer<Uint8>, Uint32);
typedef DecoderReadDart = int Function(Pointer<Void>, Pointer<Uint8>, int);
final DecoderReadDart decoderRead =
    _lib.lookupFunction<DecoderReadNative, DecoderReadDart>('decoder_read');

typedef DecoderCloseNative = Void Function(Pointer<Void>);
typedef DecoderCloseDart = void Function(Pointer<Void>);
final DecoderCloseDart decoderClose =
    _lib.lookupFunction<DecoderCloseNative, DecoderCloseDart>('decoder_close');
