import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import '../models/player_state.dart';
import '../models/protocol.dart';
import 'audio_service.dart';
import 'serial_service.dart';

const int samplesPerFrame = 254;
const int targetSampleRate = 16000;

/// 帧间隔：254 采样 ÷ 16000 Hz ≈ 15.875 ms
final frameDuration = Duration(
  microseconds: ((samplesPerFrame * 1000000) / targetSampleRate).round(),
);

class PlayerController {
  final SerialService _serialService;

  Pointer<Void>? _decoderHandle;
  Timer? _sendTimer;
  int _seq = 0;
  int _samplesSent = 0;
  int _totalSamples = 0;
  Duration _duration = Duration.zero;
  double _volume = 0.8;

  final _stateController = StreamController<PlayerState>.broadcast();
  Stream<PlayerState> get stateStream => _stateController.stream;

  PlayerState _state = PlayerState.initial();
  PlayerState get state => _state;

  bool get isActive => _sendTimer != null;

  PlayerController(this._serialService);

  void _emit(PlayerState s) {
    _state = s;
    _stateController.add(s);
  }

  /// 选择音频文件并获取信息
  Future<AudioFileInfo> selectFile(String filePath) async {
    final dec = AudioService.open(filePath, targetRate: targetSampleRate);
    _decoderHandle = dec.handle;
    _totalSamples = dec.info.totalSamples;
    _duration = dec.info.duration;
    _samplesSent = 0;
    _seq = 0;

    _emit(PlayerState(
      status: PlayStatus.idle,
      filePath: filePath,
      fileName: filePath.split('\\').last.split('/').last,
      duration: _duration,
      position: Duration.zero,
      volume: _volume,
    ));
    return dec.info;
  }

  /// 握手 + 发送格式信息
  Future<void> _handshake() async {
    // 发送 HANDSHAKE
    _serialService.write(buildCmdFrame(Cmd.handshake));
    await Future.delayed(const Duration(milliseconds: 50));
    // 发送 FORMAT
    _serialService.write(buildFormatFrame(targetSampleRate, 8, 1));
    await Future.delayed(const Duration(milliseconds: 50));
    // 发送 VOLUME
    _serialService.write(buildVolumeFrame((_volume * 255).round()));
    await Future.delayed(const Duration(milliseconds: 50));
    // 发送 PLAY
    _serialService.write(buildCmdFrame(Cmd.play));
    await Future.delayed(const Duration(milliseconds: 50));
  }

  /// 开始播放
  Future<void> play() async {
    if (_decoderHandle == null) return;

    await _handshake();

    _emit(_state.copyWith(status: PlayStatus.playing));

    _sendTimer = Timer.periodic(frameDuration, (_) {
      _sendFrame();
    });
  }

  void _sendFrame() {
    final h = _decoderHandle;
    if (h == null) return;

    final buf = Uint8List(samplesPerFrame);
    final n = AudioService.read(h, buf, samplesPerFrame);

    if (n <= 0) {
      // EOF — 自动停止
      stop();
      _emit(_state.copyWith(
        status: PlayStatus.stopped,
        position: _duration,
      ));
      return;
    }

    // 构建 DATA 帧并发送
    final frame = buildDataFrame(_seq, Uint8List.sublistView(buf, 0, n));
    try {
      _serialService.write(frame);
    } catch (_) {
      // 串口写入失败，停止播放
      stop();
      return;
    }

    _seq = (_seq + 1) & 0xFFFF;
    _samplesSent += n;

    final posMs = (_samplesSent * 1000) ~/ targetSampleRate;
    _emit(_state.copyWith(
      position: Duration(milliseconds: posMs),
    ));
  }

  /// 暂停
  void pause() {
    _sendTimer?.cancel();
    _sendTimer = null;
    _emit(_state.copyWith(status: PlayStatus.paused));
    try {
      _serialService.write(buildCmdFrame(Cmd.stop));
    } catch (_) {}
  }

  /// 从暂停恢复
  Future<void> resume() async {
    if (_decoderHandle == null) return;
    try {
      _serialService.write(buildCmdFrame(Cmd.play));
    } catch (_) {}
    _emit(_state.copyWith(status: PlayStatus.playing));
    _sendTimer = Timer.periodic(frameDuration, (_) {
      _sendFrame();
    });
  }

  /// 停止播放
  void stop() {
    _sendTimer?.cancel();
    _sendTimer = null;
    try {
      _serialService.write(buildCmdFrame(Cmd.stop));
    } catch (_) {}
    if (_decoderHandle != null) {
      AudioService.close(_decoderHandle!);
      _decoderHandle = null;
    }
    _seq = 0;
    _samplesSent = 0;
    _emit(_state.copyWith(
      status: PlayStatus.stopped,
      position: _duration,
    ));
  }

  /// 调节音量
  void setVolume(double v) {
    _volume = v.clamp(0.0, 1.0);
    _emit(_state.copyWith(volume: _volume));
    if (_serialService.isOpen) {
      try {
        _serialService.write(buildVolumeFrame((_volume * 255).round()));
      } catch (_) {}
    }
  }

  void dispose() {
    stop();
    _stateController.close();
  }
}
