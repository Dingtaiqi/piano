import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player_state.dart';
import '../services/player_controller.dart';
import 'serial_provider.dart';

/// 播放器状态
class PlayerNotifier extends StateNotifier<PlayerState> {
  PlayerController? _controller;
  final Ref _ref;

  PlayerNotifier(this._ref) : super(PlayerState.initial());

  PlayerController? get controller => _controller;

  /// 选择音频文件
  Future<void> selectFile(String filePath) async {
    final serialState = _ref.read(serialProvider);
    if (serialState is! SerialConnected) {
      state = state.copyWith(
        status: PlayStatus.idle,
        filePath: filePath,
        fileName: filePath.split('\\').last.split('/').last,
      );
      return;
    }

    final svcNotifier = _ref.read(serialProvider.notifier);
    _controller = PlayerController(svcNotifier.service);

    try {
      await _controller!.selectFile(filePath);
      state = _controller!.state;
    } catch (e) {
      state = state.copyWith(status: PlayStatus.idle);
    }
  }

  /// 播放
  Future<void> play() async {
    if (_controller == null) return;
    try {
      await _controller!.play();
      state = _controller!.state;
    } catch (e) {
      state = state.copyWith(status: PlayStatus.idle);
    }
  }

  /// 暂停
  void pause() {
    _controller?.pause();
  }

  /// 恢复播放
  Future<void> resume() async {
    await _controller?.resume();
  }

  /// 停止
  void stop() {
    _controller?.stop();
  }

  /// 调节音量
  void setVolume(double v) {
    _controller?.setVolume(v);
  }
}

final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(ref);
});
