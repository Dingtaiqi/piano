import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/serial_bar.dart';
import '../widgets/midi_card.dart';

final debugLogProvider = StateProvider<String>((ref) => '');

void addDebugLog(WidgetRef ref, String msg) {
  final t = DateTime.now().toString().substring(11, 19);
  ref.read(debugLogProvider.notifier).state += '[$t] $msg\n';
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debugLog = ref.watch(debugLogProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('EDA 电子琴')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const SerialBar(),
          const SizedBox(height: 12),
          const MidiCard(),
          const SizedBox(height: 12),
          Card(
            child: ExpansionTile(
              leading: Icon(Icons.monitor_heart_outlined, size: 20, color: cs.onSurfaceVariant),
              title: Text('串口监视', style: Theme.of(context).textTheme.titleSmall),
              subtitle: Text(debugLog.isEmpty ? '无数据' : debugLog.split('\n').where((l) => l.isNotEmpty).length.toString(),
                  style: Theme.of(context).textTheme.labelSmall),
              children: [
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: debugLog.isEmpty
                      ? Center(child: Text('暂无数据', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(debugLog, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: () => ref.read(debugLogProvider.notifier).state = '', child: const Text('清空')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
