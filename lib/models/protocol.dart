import 'dart:typed_data';

/// 协议命令常量
class Cmd {
  // Host → ESP8266
  static const int handshake = 0x01;
  static const int format = 0x02;
  static const int play = 0x03;
  static const int stop = 0x04;
  static const int data = 0x05;
  static const int volume = 0x06;
  static const int ping = 0x07;
  static const int reset = 0x08;

  // ESP8266 → Host
  static const int ack = 0x80;
  static const int nack = 0x81;
  static const int ready = 0x82;
  static const int error = 0x83;
}

const int sync1 = 0xAA;
const int sync2 = 0x55;
const int maxPayload = 1024;

/// CRC8 (Dallas/Maxim, 多项式 0x31 反射)
int crc8(Uint8List data) {
  int crc = 0x00;
  for (final byte in data) {
    int b = byte;
    for (int i = 0; i < 8; i++) {
      final mix = (crc ^ b) & 0x01;
      crc >>= 1;
      if (mix != 0) crc ^= 0x8C;
      b >>= 1;
    }
  }
  return crc;
}

/// 构建协议帧
Uint8List buildFrame(int cmd, Uint8List payload) {
  final len = payload.length;
  assert(len <= maxPayload, 'payload too large');

  final frame = Uint8List(5 + len + 1);
  frame[0] = sync1;
  frame[1] = sync2;
  frame[2] = cmd;
  frame[3] = (len >> 8) & 0xFF;
  frame[4] = len & 0xFF;
  frame.setAll(5, payload);

  // CRC8 over CMD+LEN+PAYLOAD
  final crcInput = Uint8List(3 + len);
  crcInput[0] = cmd;
  crcInput[1] = frame[3];
  crcInput[2] = frame[4];
  crcInput.setAll(3, payload);
  frame[5 + len] = crc8(crcInput);

  return frame;
}

/// 构建简单命令帧 (无载荷)
Uint8List buildCmdFrame(int cmd) => buildFrame(cmd, Uint8List(0));

/// 构建 DATA 帧
Uint8List buildDataFrame(int seq, Uint8List samples) {
  final payload = Uint8List(2 + samples.length);
  payload[0] = seq & 0xFF;
  payload[1] = (seq >> 8) & 0xFF;
  payload.setAll(2, samples);
  return buildFrame(Cmd.data, payload);
}

/// 构建 FORMAT 帧
Uint8List buildFormatFrame(int sampleRate, int bitsPerSample, int channels) {
  final payload = Uint8List(6);
  payload[0] = sampleRate & 0xFF;
  payload[1] = (sampleRate >> 8) & 0xFF;
  payload[2] = (sampleRate >> 16) & 0xFF;
  payload[3] = (sampleRate >> 24) & 0xFF;
  payload[4] = bitsPerSample;
  payload[5] = channels;
  return buildFrame(Cmd.format, payload);
}

/// 构建 VOLUME 帧
Uint8List buildVolumeFrame(int level) {
  return buildFrame(Cmd.volume, Uint8List.fromList([level]));
}

/// 解析帧，返回 (cmd, payload) 或 null
(int, Uint8List)? parseFrame(Uint8List frame) {
  if (frame.length < 6) return null;
  if (frame[0] != sync1 || frame[1] != sync2) return null;

  final cmd = frame[2];
  final len = ((frame[3] << 8) | frame[4]) as int;

  if (frame.length != 5 + len + 1) return null;

  final payload = frame.sublist(5, 5 + len);
  final expectedCrc = crc8(frame.sublist(2, 5 + len));
  if (frame[5 + len] != expectedCrc) return null;

  return (cmd, payload);
}
