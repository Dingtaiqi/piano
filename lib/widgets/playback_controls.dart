import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player_state.dart';
import '../providers/player_provider.dart';
import '../providers/serial_provider.dart';

class PlaybackControls extends ConsumerWidget {
  const PlaybackControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final serialConnected = ref.watch(serialProvider) is SerialConnected;
    final hasFile = player.filePath != null;
    final canControl = hasFile && serialConnected;
    final isPlaying = player.status == PlayStatus.playing;
    final isPaused = player.status == PlayStatus.paused;
    final isIdle = player.status == PlayStatus.idle;
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.play_circle_outline, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text('控制', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 播放/暂停按钮
                _CircleButton(
                  onTap: !canControl
                      ? null
                      : () {
                          final notifier = ref.read(playerProvider.notifier);
                          if (isPlaying) {
                            notifier.pause();
                          } else if (isPaused) {
                            notifier.resume();
                          } else {
                            notifier.play();
                          }
                        },
                  icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  filled: true,
                  size: 72,
                ),
                const SizedBox(width: 32),
                // 停止按钮
                _CircleButton(
                  onTap: !canControl || isIdle
                      ? null
                      : () => ref.read(playerProvider.notifier).stop(),
                  icon: Icons.stop_rounded,
                  filled: false,
                  size: 56,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final bool filled;
  final double size;

  const _CircleButton({
    required this.onTap,
    required this.icon,
    required this.filled,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: filled ? cs.primaryContainer : cs.surfaceContainerHighest,
      shape: CircleBorder(
        side: filled ? BorderSide.none : BorderSide(color: cs.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.45,
            color: onTap != null
                ? (filled ? cs.onPrimaryContainer : cs.onSurface)
                : cs.onSurface.withAlpha(60),
          ),
        ),
      ),
    );
  }
}
