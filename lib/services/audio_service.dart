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
  /// 初始化 FFmpeg 目录，必须在 open 之前调用。可重复调用切换路径。
  static void init(String ffmpegDir) {
    final ptr = ffmpegDir.toNativeUtf8();
    decoderSetFfmpegDir(ptr);
    calloc.free(ptr);
  }

  static AudioDecoderHandle open(String filePath, {int targetRate = 16000}) {
    final pathPtr = filePath.toNativeUtf8();
    final handle = decoderOpen(pathPtr, targetRate);
    calloc.free(pathPtr);

    if (handle == nullptr) {
      throw Exception('ffmpeg 启动失败。请确认:\n'
          '1. 已选择 ffmpeg 所在目录\n'
          '2. 终端执行 chmod +x ffmpeg ffprobe\n'
          '3. 终端执行 xattr -cr ffmpeg ffprobe');
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
