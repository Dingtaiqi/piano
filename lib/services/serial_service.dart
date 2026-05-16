import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import '../models/serial_port_info.dart';
import 'native_bridge.dart';

class SerialService {
  Pointer<Void>? _handle;
  String? _portName;

  bool get isOpen => _handle != null;
  String? get portName => _portName;

  /// 枚举可用串口
  static List<SerialPortInfo> listPorts() {
    final ptr = serialEnumerate();
    if (ptr == nullptr) return [];
    final json = ptr.toDartString();
    serialFreeString(ptr);
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => SerialPortInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
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
