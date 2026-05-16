import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/serial_port_info.dart';
import '../providers/serial_provider.dart';

const defaultBaudRates = [921600, 460800, 230400, 115200, 9600];

class SerialBar extends ConsumerStatefulWidget {
  const SerialBar({super.key});

  @override
  ConsumerState<SerialBar> createState() => _SerialBarState();
}

class _SerialBarState extends ConsumerState<SerialBar> {
  SerialPortInfo? _selectedPort;
  int _selectedBaud = 921600;

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
            // 标题 + 状态
            Row(
              children: [
                Icon(Icons.usb_rounded, color: isConnected ? cs.primary : cs.onSurfaceVariant, size: 18),
                const SizedBox(width: 6),
                Text('串口', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                if (isConnected) ...[
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary),
                  ),
                  const SizedBox(width: 4),
                  Text(connectedLabel, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.primary)),
                ] else ...[
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: cs.error),
                  ),
                  const SizedBox(width: 4),
                  Text('未连接', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.error)),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // 端口 + 波特率 + 按钮 一行紧凑排列
            Row(
              children: [
                // 端口下拉
                Expanded(
                  flex: 3,
                  child: portsAsync.when(
                    data: (ports) => DropdownButtonFormField<SerialPortInfo>(
                      value: _selectedPort,
                      isExpanded: true,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: '端口',
                        prefixIcon: Icon(Icons.cable_rounded, size: 20),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: ports.isEmpty
                          ? null
                          : ports.map((p) => DropdownMenuItem(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: isConnected ? null : (v) => setState(() => _selectedPort = v),
                    ),
                    loading: () => const SizedBox(height: 40, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))),
                    error: (_, __) => Text('获取失败', style: TextStyle(color: cs.error, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),

                // 波特率下拉
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    value: _selectedBaud,
                    isExpanded: true,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: '波特率',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: defaultBaudRates.map((b) => DropdownMenuItem(value: b, child: Text('$b', style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: isConnected ? null : (v) => setState(() => _selectedBaud = v!),
                  ),
                ),
                const SizedBox(width: 8),

                // 连接/断开按钮
                isConnecting
                    ? const SizedBox(width: 40, height: 40, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
                    : FilledButton(
                        onPressed: isConnected
                            ? () => ref.read(serialProvider.notifier).disconnect()
                            : _selectedPort != null
                                ? () => ref.read(serialProvider.notifier).connect(_selectedPort!.name, _selectedBaud)
                                : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(56, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: Icon(isConnected ? Icons.link_off_rounded : Icons.link_rounded, size: 20),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
