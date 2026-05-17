import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import '../models/serial_port_info.dart';
import 'native_bridge.dart';

class SerialService {
  Pointer<Void>? _handle;
  String? _portName;

  bool get isOpen => _handle != null;
  String? get portName => _portName;

  /// 枚举可用串口 (系统命令，零依赖)
  static List<SerialPortInfo> listPorts() {
    final ports = <SerialPortInfo>[];
    try {
      if (Platform.isWindows) {
        // WMIC 查询串口
        final result = Process.runSync('wmic', ['path', 'Win32_SerialPort', 'get', 'DeviceID'], runInShell: true);
        for (final line in result.stdout.toString().split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty && trimmed != 'DeviceID') {
            ports.add(SerialPortInfo(name: trimmed, description: ''));
          }
        }
      } else if (Platform.isMacOS) {
        // macOS: /dev/cu.* 是串口设备
        final result = Process.runSync('ls', ['/dev/cu.*'], runInShell: true);
        for (final line in result.stdout.toString().split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            ports.add(SerialPortInfo(name: trimmed, description: ''));
          }
        }
        // Fallback: also try /dev/tty.* if cu.* returns nothing
        if (ports.isEmpty) {
          final result2 = Process.runSync('ls', ['/dev/tty.*'], runInShell: true);
          for (final line in result2.stdout.toString().split('\n')) {
            final trimmed = line.trim();
            if (trimmed.isNotEmpty && !trimmed.contains('Bluetooth')) {
              ports.add(SerialPortInfo(name: trimmed, description: ''));
            }
          }
        }
      }
      // Also try Rust enumeration as fallback
      if (ports.isEmpty) {
        ports.addAll(_listPortsRust());
      }
    } catch (_) {}
    return ports;
  }

  static List<SerialPortInfo> _listPortsRust() {
    final ptr = serialEnumerate();
    if (ptr == nullptr) return [];
    final json = ptr.toDartString();
    serialFreeString(ptr);
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => SerialPortInfo.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static jsonDecode(String s) {
    // Simple JSON array parser for [{name, description}] format
    final result = <Map<String, dynamic>>[];
    final names = RegExp(r'"name"\s*:\s*"([^"]*)"');
    final descs = RegExp(r'"description"\s*:\s*"([^"]*)"');
    final objects = s.split('},{');
    for (final obj in objects) {
      final n = names.firstMatch(obj);
      final d = descs.firstMatch(obj);
      if (n != null) {
        result.add({'name': n.group(1)!, 'description': d?.group(1) ?? ''});
      }
    }
    return result;
  }

  /// 打开串口
  void open(String portName, int baudRate) {
    if (_handle != null) close();
    final namePtr = portName.toNativeUtf8();
    _handle = serialOpen(namePtr, baudRate);
    calloc.free(namePtr);
    if (_handle == nullptr) {
      throw Exception('无法打开串口: $portName');
    }
    _portName = portName;
  }

  /// 写入数据
  int write(Uint8List data) {
    final h = _handle;
    if (h == null) throw StateError('串口未打开');
    final ptr = calloc.allocate<Uint8>(data.length);
    for (int i = 0; i < data.length; i++) {
      ptr[i] = data[i];
    }
    final result = serialWrite(h, ptr, data.length);
    calloc.free(ptr);
    if (result < 0) throw Exception('串口写入失败');
    return result;
  }

  /// 读取数据 (带超时，毫秒)
  Uint8List? read(int maxLen, int timeoutMs) {
    final h = _handle;
    if (h == null) throw StateError('串口未打开');
    final ptr = calloc.allocate<Uint8>(maxLen);
    final result = serialRead(h, ptr, maxLen, timeoutMs);
    if (result <= 0) {
      calloc.free(ptr);
      return null;
    }
    final data = Uint8List(result);
    for (int i = 0; i < result; i++) {
      data[i] = ptr[i];
    }
    calloc.free(ptr);
    return data;
  }

  /// 关闭串口
  void close() {
    if (_handle != null) {
      serialClose(_handle!);
      _handle = null;
      _portName = null;
    }
  }
}
