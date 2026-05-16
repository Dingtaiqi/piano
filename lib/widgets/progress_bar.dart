import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';

class PlaybackProgressBar extends ConsumerWidget {
  const PlaybackProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final hasMedia = player.duration.inMilliseconds > 0;
    final cs = Theme.of(context).colorScheme;

    final positionMs = hasMedia
        ? player.position.inMilliseconds.clamp(0, player.duration.inMilliseconds)
        : 0;
    final totalMs = hasMedia ? player.duration.inMilliseconds : 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: cs.primary,
                inactiveTrackColor: cs.surfaceContainerHighest,
                thumbColor: cs.primary,
                overlayColor: cs.primary.withAlpha(25),
              ),
              child: Slider(
                value: positionMs.toDouble(),
                max: totalMs.toDouble(),
                onChanged: null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmt(Duration(milliseconds: positionMs)),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onSurface,
                        ),
                  ),
                  Text(
                    _fmt(Duration(milliseconds: totalMs > 0 ? totalMs : 0)),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
