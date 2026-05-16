import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/player_provider.dart';
import '../providers/serial_provider.dart';

class FilePickerCard extends ConsumerWidget {
  const FilePickerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final hasFile = playerState.filePath != null;
    final serialConnected = ref.watch(serialProvider) is SerialConnected;
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.audio_file_rounded, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text('音频文件', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),

            // 文件信息卡片
            if (hasFile)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.music_note_rounded, color: cs.onPrimaryContainer),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playerState.fileName ?? '未知',
                            style: Theme.of(context).textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDuration(playerState.duration),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.outlineVariant.withAlpha(80),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Center(
                  child: Text(
                    '选择音频文件开始播放',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // 选择文件按钮
            OutlinedButton.icon(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['mp3', 'wav', 'flac', 'ogg', 'm4a', 'aac'],
                );
                if (result != null && result.files.single.path != null) {
                  ref.read(playerProvider.notifier).selectFile(result.files.single.path!);
                }
              },
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(hasFile ? '更换文件' : '选择音频文件'),
            ),

            // 未连接串口提示
            if (!serialConnected && hasFile)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: cs.error),
                    const SizedBox(width: 6),
                    Text('请先连接串口', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.error)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
