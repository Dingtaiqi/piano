enum PlayStatus { idle, playing, paused, stopped }

class PlayerState {
  final PlayStatus status;
  final String? filePath;
  final String? fileName;
  final Duration duration;
  final Duration position;
  final double volume; // 0.0 - 1.0
  final int sampleRate;
  final int channels;

  final String? errorMessage;

  const PlayerState({
    this.status = PlayStatus.idle,
    this.filePath,
    this.fileName,
    this.duration = Duration.zero,
    this.position = Duration.zero,
    this.volume = 0.8,
    this.sampleRate = 16000,
    this.channels = 1,
    this.errorMessage,
  });

  PlayerState copyWith({
    PlayStatus? status,
    String? filePath,
    String? fileName,
    Duration? duration,
    Duration? position,
    double? volume,
    int? sampleRate,
    int? channels,
    String? errorMessage,
  }) {
    return PlayerState(
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      volume: volume ?? this.volume,
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  factory PlayerState.initial() => const PlayerState();
}
