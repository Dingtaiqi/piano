import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'native_bridge.dart';

class AudioFileInfo {
  final int sampleRate;
  final int totalSamples;
  final Duration duration;
  final int channels;

  const AudioFileInfo({
    required this.sampleRate,
    required this.totalSamples,
    required this.duration,
    required this.channels,
  });
}

class AudioDecoderHandle {
  final Pointer<Void> handle;
  final AudioFileInfo info;

  const AudioDecoderHandle({required this.handle, required this.info});
}

class AudioService {
  static bool _initialized = false;

  /// 初始化 FFmpeg 目录，必须在 open 之前调用
  static void init(String ffmpegDir) {
    if (_initialized) return;
    final ptr = ffmpegDir.toNativeUtf8();
    decoderSetFfmpegDir(ptr);
    calloc.free(ptr);
    _initialized = true;
  }

  static AudioDecoderHandle open(String filePath, {int targetRate = 16000}) {
    final pathPtr = filePath.toNativeUtf8();
    final handle = decoderOpen(pathPtr, targetRate);
    calloc.free(pathPtr);

    if (handle == nullptr) {
      throw Exception('无法打开音频文件: $filePath\n'
          '请确认 ffmpeg 已安装并加入 PATH 环境变量');
    }

    final infoPtr = calloc.allocate<DecoderInfo>(sizeOf<DecoderInfo>());
    final ret = decoderGetInfo(handle, infoPtr);

    if (ret != 0) {
      decoderClose(handle);
      calloc.free(infoPtr);
      throw Exception('获取音频信息失败');
    }

    final info = AudioFileInfo(
      sampleRate: infoPtr.ref.sampleRate,
      totalSamples: infoPtr.ref.totalSamples,
      duration: Duration(milliseconds: infoPtr.ref.durationMs),
      channels: infoPtr.ref.channels,
    );
    calloc.free(infoPtr);

    return AudioDecoderHandle(handle: handle, info: info);
  }

  /// 流式读取 PCM 数据 (8-bit 无符号)
  static int read(Pointer<Void> handle, Uint8List buf, int maxSamples) {
    final ptr = calloc.allocate<Uint8>(maxSamples);
    final n = decoderRead(handle, ptr, maxSamples);
    if (n > 0) {
      for (int i = 0; i < n; i++) {
        buf[i] = ptr[i];
      }
    }
    calloc.free(ptr);
    return n;
  }

  static void close(Pointer<Void> handle) {
    decoderClose(handle);
  }
}
