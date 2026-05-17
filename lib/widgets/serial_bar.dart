import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/serial_provider.dart';

const defaultBaudRates = [115200, 921600, 460800, 230400, 9600];

class SerialBar extends ConsumerStatefulWidget {
  const SerialBar({super.key});

  @override
  ConsumerState<SerialBar> createState() => _SerialBarState();
}

class _SerialBarState extends ConsumerState<SerialBar> {
  String? _selectedPort;
  int _selectedBaud = 115200;

  @override
  Widget build(BuildContext context) {
    ref.watch(serialAutoRefreshProvider);
    final connectionState = ref.watch(serialProvider);
    final portsAsync = ref.watch(serialPortsProvider);
    final isConnected = connectionState is SerialConnected;
    final isConnecting = connectionState is SerialConnecting;
    final cs = Theme.of(context).colorScheme;
    final connected = connectionState is SerialConnected ? connectionState : null;
    final connectedLabel = connected != null ? '${connected.portName} @ ${connected.baudRate}' : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.usb_rounded, color: isConnected ? cs.primary : cs.onSurfaceVariant, size: 18),
              const SizedBox(width: 6),
              Text('串口', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              if (isConnected) ...[
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary)),
                const SizedBox(width: 4),
                Text(connectedLabel, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.primary)),
              ] else ...[
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: cs.error)),
                const SizedBox(width: 4),
                Text('未连接', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.error)),
              ],
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                flex: 3,
                child: portsAsync.when(
                  data: (ports) {
                    final names = ports.map((p) => p.name).toList();
                    if (names.isEmpty) {
                      return const TextField(enabled: false, decoration: InputDecoration(labelText: '未检测到串口'));
                    }
                    return DropdownMenu<String>(
                      initialSelection: names.contains(_selectedPort) ? _selectedPort : null,
                      expandedInsets: EdgeInsets.zero,
                      enableFilter: false,
                      enabled: !isConnected,
                      label: const Text('端口'),
                      leadingIcon: const Icon(Icons.cable_rounded, size: 20),
                      onSelected: (v) => setState(() => _selectedPort = v),
                      dropdownMenuEntries: names.map((n) => DropdownMenuEntry(value: n, label: n)).toList(),
                    );
                  },
                  loading: () => const SizedBox(height: 56, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))),
                  error: (_, __) => Text('获取失败', style: TextStyle(color: cs.error, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownMenu<int>(
                  initialSelection: defaultBaudRates.contains(_selectedBaud) ? _selectedBaud : 115200,
                  expandedInsets: EdgeInsets.zero,
                  enableFilter: false,
                  enabled: !isConnected,
                  label: const Text('波特率'),
                  onSelected: (v) => setState(() => _selectedBaud = v ?? 115200),
                  dropdownMenuEntries: defaultBaudRates.map((b) => DropdownMenuEntry(value: b, label: '$b')).toList(),
                ),
              ),
              const SizedBox(width: 8),
              isConnecting
                  ? const SizedBox(width: 40, height: 40, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
                  : FilledButton(
                      onPressed: isConnected
                          ? () => ref.read(serialProvider.notifier).disconnect()
                          : _selectedPort != null ? () => ref.read(serialProvider.notifier).connect(_selectedPort!, _selectedBaud) : null,
                      style: FilledButton.styleFrom(minimumSize: const Size(56, 40), padding: const EdgeInsets.symmetric(horizontal: 12)),
                      child: Icon(isConnected ? Icons.link_off_rounded : Icons.link_rounded, size: 20),
                    ),
            ]),
          ],
        ),
      ),
    );
  }
}
