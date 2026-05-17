import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/protocol.dart';
import '../pages/home_page.dart';
import '../providers/serial_provider.dart';
import '../services/midi_service.dart';

enum TeachState { idle, teaching, completed }

class MidiCard extends ConsumerStatefulWidget {
  const MidiCard({super.key});

  @override
  ConsumerState<MidiCard> createState() => _MidiCardState();
}

class _MidiCardState extends ConsumerState<MidiCard> {
  MidiMelody? _melody;
  bool _sending = false;

  // 跟弹教学状态
  TeachState _teachState = TeachState.idle;
  int _teachNoteIndex = 0;
  int _teachTotalNotes = 0;
  String _teachFeedback = '';
  Timer? _teachTimer;

  static const _keyNames = ['', 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

  @override
  void dispose() {
    _teachTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['mid', 'midi'],
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final melody = MidiService.parse(result.files.single.path!);
    if (melody == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MIDI 解析失败'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }
    setState(() {
      _melody = melody;
      _teachState = TeachState.idle;
      _teachFeedback = '';
    });
  }

  Future<void> _sendMelody() async {
    final svc = ref.read(serialProvider.notifier).service;
    final name = _melody!.name;
    var notes = _melody!.notes;
    if (notes.length > 512) {
      notes = notes.sublist(0, 512);
      addDebugLog(ref, '截断: ${_melody!.noteCount} → 512 音符');
    }

    final nameBytes = Uint8List(32);
    for (int i = 0; i < name.length && i < 32; i++) {
      nameBytes[i] = name.codeUnitAt(i);
    }

    final payload = Uint8List(32 + 2 + notes.length);
    payload.setAll(0, nameBytes);
    payload[32] = (notes.length >> 8) & 0xFF;
    payload[33] = notes.length & 0xFF;
    payload.setAll(34, notes);

    final frame = buildFrame(0x10, payload);
    addDebugLog(ref, '发送 MELODY: ${frame.length}B, notes=${notes.length}');
    svc.write(frame);
    await Future.delayed(const Duration(milliseconds: 200));
    final resp = svc.read(32, 100);
    if (resp != null) {
      addDebugLog(ref, 'ACK: ${_hex(resp)}');
    } else {
      addDebugLog(ref, '无响应');
    }
  }

  Future<void> _autoPlay() async {
    final serial = ref.read(serialProvider);
    if (serial is! SerialConnected || _melody == null) return;

    setState(() => _sending = true);
    try {
      await _sendMelody();

      final svc = ref.read(serialProvider.notifier).service;
      final frame = buildFrame(0x11, Uint8List(0));
      addDebugLog(ref, '发送 PLAY');
      svc.write(frame);
      await Future.delayed(const Duration(milliseconds: 100));
      final resp = svc.read(32, 100);
      if (resp != null) {
        addDebugLog(ref, 'ACK: ${_hex(resp)}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('自动播放: ${_melody!.name} (${_melody!.notes.length} 音符)'), behavior: SnackBarBehavior.floating),
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

  Future<void> _startTeaching() async {
    final serial = ref.read(serialProvider);
    if (serial is! SerialConnected || _melody == null) return;

    setState(() => _sending = true);
    try {
      await _sendMelody();

      final svc = ref.read(serialProvider.notifier).service;
      final frame = buildFrame(0x12, Uint8List(0));
      addDebugLog(ref, '发送 TEACH');
      svc.write(frame);
      await Future.delayed(const Duration(milliseconds: 100));
      final resp = svc.read(32, 100);
      if (resp != null) {
        addDebugLog(ref, 'ACK: ${_hex(resp)}');
      }

      setState(() {
        _teachState = TeachState.teaching;
        _teachTotalNotes = _melody!.notes.length;
        _teachNoteIndex = 0;
        _teachFeedback = '等待第一个音符...';
      });

      _teachTimer = Timer.periodic(const Duration(milliseconds: 250), (_) => _pollTeachEvents());
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

  void _pollTeachEvents() {
    if (_teachState != TeachState.teaching) return;

    final svc = ref.read(serialProvider.notifier).service;
    final data = svc.read(64, 50);
    if (data == null || data.isEmpty) return;

    addDebugLog(ref, '事件: ${_hex(data)}');

    int offset = 0;
    while (offset + 6 <= data.length) {
      final frameEnd = _findFrame(data, offset);
      if (frameEnd == -1) break;

      final frame = Uint8List.sublistView(data, offset, frameEnd + 1);
      final parsed = parseFrame(frame);
      if (parsed != null) {
        final (cmd, payload) = parsed;
        if (cmd == 0x82 && payload.length >= 6) {
          _onTeachEvent(payload);
        }
      }
      offset = frameEnd + 1;
    }
  }

  int _findFrame(Uint8List data, int start) {
    for (int i = start; i < data.length - 1; i++) {
      if (data[i] == 0xAA && data[i + 1] == 0x55) {
        // found sync, calculate total frame length
        if (i + 5 >= data.length) return -1; // incomplete header
        final payloadLen = (data[i + 3] << 8) | data[i + 4];
        final frameEnd = i + 5 + payloadLen;
        if (frameEnd >= data.length) return -1; // incomplete frame
        return frameEnd;
      }
    }
    return -1;
  }

  void _onTeachEvent(Uint8List payload) {
    final eventType = payload[0];
    final noteIndex = (payload[1] << 8) | payload[2];
    final totalNotes = (payload[3] << 8) | payload[4];
    final noteValue = payload[5];

    setState(() {
      _teachTotalNotes = totalNotes;
      _teachNoteIndex = noteIndex;

      switch (eventType) {
        case 0x01: // SHOW_NOTE
          _teachFeedback = '请弹奏: ${_keyNames[noteValue]}';
        case 0x02: // CORRECT
          _teachFeedback = '正确! ${_keyNames[noteValue]}';
        case 0x03: // WRONG
          _teachFeedback = '错误，请重试 ${_keyNames[noteValue]}';
        case 0x04: // COMPLETE
          _teachFeedback = '完成!';
          _teachState = TeachState.completed;
          _teachTimer?.cancel();
          _teachTimer = null;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('跟弹完成!'), behavior: SnackBarBehavior.floating),
            );
          }
      }
    });
  }

  void _stopTeaching() {
    final svc = ref.read(serialProvider.notifier).service;
    final frame = buildFrame(0x13, Uint8List(0));
    svc.write(frame);
    addDebugLog(ref, '发送 STOP');

    _teachTimer?.cancel();
    _teachTimer = null;
    setState(() {
      _teachState = TeachState.idle;
      _teachFeedback = '';
    });
  }

  String _hex(Uint8List data) {
    return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final serialState = ref.watch(serialProvider);
    final connected = serialState is SerialConnected;
    final cs = Theme.of(context).colorScheme;
    final isTeaching = _teachState == TeachState.teaching;

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

            // 跟弹进度
            if (isTeaching || _teachState == TeachState.completed) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _teachState == TeachState.completed ? cs.primaryContainer : cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(children: [
                  Row(children: [
                    Icon(_teachState == TeachState.completed ? Icons.check_circle : Icons.lightbulb_outline, size: 18, color: cs.onTertiaryContainer),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_teachFeedback, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
                    if (isTeaching)
                      Text('${_teachNoteIndex + 1}/$_teachTotalNotes', style: Theme.of(context).textTheme.labelSmall),
                  ]),
                  const SizedBox(height: 8),
                  if (_teachTotalNotes > 0)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _teachTotalNotes > 0 ? (_teachNoteIndex + 1) / _teachTotalNotes : 0,
                        minHeight: 6,
                      ),
                    ),
                ]),
              ),
            ],

            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickAndParse,
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: Text(_melody != null ? '更换' : '选择文件', style: const TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                ),
              ),
              if (connected && _melody != null && !_sending && !isTeaching) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _autoPlay,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('自动播放', style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _startTeaching,
                    icon: const Icon(Icons.school_rounded, size: 18),
                    label: const Text('跟弹练习', style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      backgroundColor: cs.tertiary,
                    ),
                  ),
                ),
              ] else if (isTeaching) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _stopTeaching,
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: const Text('停止', style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      backgroundColor: cs.error,
                    ),
                  ),
                ),
              ] else if (_sending) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: null,
                    icon: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    label: const Text('发送中...', style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  ),
                ),
              ],
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
