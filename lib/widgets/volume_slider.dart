import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';

class VolumeSlider extends ConsumerWidget {
  const VolumeSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(playerProvider).volume;
    final cs = Theme.of(context).colorScheme;

    final icon = volume == 0
        ? Icons.volume_off_rounded
        : volume < 0.5
            ? Icons.volume_down_rounded
            : Icons.volume_up_rounded;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: cs.onSurfaceVariant, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: cs.primary,
                  inactiveTrackColor: cs.surfaceContainerHighest,
                  thumbColor: cs.primary,
                  overlayColor: cs.primary.withAlpha(25),
                ),
                child: Slider(
                  value: volume,
                  onChanged: (v) => ref.read(playerProvider.notifier).setVolume(v),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              child: Text(
                '${(volume * 100).round()}%',
                style: Theme.of(context).textTheme.labelMedium,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
