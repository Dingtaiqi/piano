import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/serial_port_info.dart';
import '../services/serial_service.dart';

/// 串口连接状态
sealed class SerialConnectionState {
  const SerialConnectionState();
}

class SerialDisconnected extends SerialConnectionState {
  const SerialDisconnected();
}

class SerialConnecting extends SerialConnectionState {
  const SerialConnecting();
}

class SerialConnected extends SerialConnectionState {
  final String portName;
  final int baudRate;
  const SerialConnected({required this.portName, required this.baudRate});
}

class SerialError extends SerialConnectionState {
  final String message;
  const SerialError(this.message);
}

/// 可用串口列表
final serialPortsProvider = FutureProvider<List<SerialPortInfo>>((ref) {
  return SerialService.listPorts();
});

/// 串口连接状态
class SerialNotifier extends StateNotifier<SerialConnectionState> {
  final SerialService _service;

  SerialNotifier(this._service) : super(const SerialDisconnected());

  SerialService get service => _service;

  void connect(String portName, int baudRate) async {
    state = const SerialConnecting();
    try {
      _service.open(portName, baudRate);
      state = SerialConnected(portName: portName, baudRate: baudRate);
    } catch (e) {
      state = SerialError(e.toString());
      state = const SerialDisconnected();
    }
  }

  void disconnect() {
    _service.close();
    state = const SerialDisconnected();
  }
}

/// 串口列表自动刷新定时器
final serialAutoRefreshProvider = Provider<AutoDisposeTimer>(
  (ref) {
    final timer = Timer.periodic(const Duration(seconds: 2), (_) {
      ref.invalidate(serialPortsProvider);
    });
    ref.onDispose(timer.cancel);
    return AutoDisposeTimer._(timer);
  },
);

/// 包装类用于 provider
class AutoDisposeTimer {
  final Timer _timer;
  AutoDisposeTimer._(this._timer);
}

final serialProvider =
    StateNotifierProvider<SerialNotifier, SerialConnectionState>((ref) {
  final service = SerialService();
  ref.onDispose(() => service.close());
  return SerialNotifier(service);
});
