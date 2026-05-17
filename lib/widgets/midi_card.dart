import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/protocol.dart';
import '../pages/home_page.dart';
import '../providers/serial_provider.dart';
import '../services/midi_service.dart';

class MidiCard extends ConsumerStatefulWidget {
  const MidiCard({super.key});

  @override
  ConsumerState<MidiCard> createState() => _MidiCardState();
}

class _MidiCardState extends ConsumerState<MidiCard> {
  MidiMelody? _melody;
  bool _sending = false;

  Future<void> _pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['mid', 'midi'],
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final melody = MidiService.parse(result.files.single.path!);
    if (melody == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MIDI 解析失败'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _melody = melody);
  }

  Future<void> _send() async {
    final serial = ref.read(serialProvider);
    if (serial is! SerialConnected || _melody == null) return;

    setState(() => _sending = true);
    try {
      final svc = ref.read(serialProvider.notifier).service;
      final name = _melody!.name;
      final notes = _melody!.notes;

      final nameBytes = Uint8List(32);
      for (int i = 0; i < name.length && i < 32; i++) {
        nameBytes[i] = name.codeUnitAt(i);
      }

      final payload = Uint8List(32 + 2 + notes.length);
      payload.setAll(0, nameBytes);
      payload[32] = (notes.length >> 8) & 0xFF;
      payload[33] = notes.length & 0xFF;
      payload.setAll(34, notes);

      final frame1 = buildFrame(0x10, payload);
      addDebugLog(ref, '发送 MELODY: ${frame1.length} 字节, payload=${payload.length}B');
      svc.write(frame1);
      await Future.delayed(const Duration(milliseconds: 200));

      final frame2 = buildFrame(0x11, Uint8List(0));
      addDebugLog(ref, '发送 PLAY');
      svc.write(frame2);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已发送: $name (${notes.length} 音符)'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final serialState = ref.watch(serialProvider);
    final connected = serialState is SerialConnected;
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.piano_rounded, color: _melody != null ? cs.primary : cs.onSurfaceVariant, size: 20),
              const SizedBox(width: 8),
              Text('MIDI 乐谱', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              if (_melody != null)
                Text('${_melody!.noteCount} 音符', style: Theme.of(context).textTheme.labelSmall),
            ]),
            const SizedBox(height: 12),
            if (_melody != null && _melody!.noteCount > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_melody!.notes.take(80).join(' '),
                    style: Theme.of(context).textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('选择 MIDI 文件', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickAndParse,
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: Text(_melody != null ? '更换' : '选择文件', style: const TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: connected && _melody != null && !_sending ? _send : null,
                  icon: _sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: const Text('发送', style: TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                ),
              ),
            ]),
            if (_melody != null && !connected)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 14, color: cs.error),
                  const SizedBox(width: 4),
                  Text('请先连接串口', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.error)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
