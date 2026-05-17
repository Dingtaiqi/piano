#include "pcm_audio.h"
#include "config.h"
#include <Ticker.h>

// ===== 环形缓冲区 =====
static volatile uint8_t ringBuf[PCM_RING_BUF_SIZE];
static volatile uint16_t readIdx = 0;
static volatile uint16_t writeIdx = 0;

// ===== 播放状态 =====
static volatile bool playing = false;
static volatile uint8_t volume = 255;  // 0-255 音量缩放

// ===== 协议解析状态机 =====
enum ParseState { WAIT_SYNC1, WAIT_SYNC2, WAIT_CMD, WAIT_LEN_H, WAIT_LEN_L, WAIT_PAYLOAD, WAIT_CRC };
static ParseState parseState = WAIT_SYNC1;
static uint8_t rxCmd = 0;
static uint16_t rxPayloadLen = 0;
static uint16_t rxPayloadIdx = 0;
static uint8_t rxPayloadBuf[1024];

// ===== 定时器 =====
static Ticker sampleTimer;

// ===== 辅助函数 =====
static uint16_t bufCount() {
  return (writeIdx - readIdx) % PCM_RING_BUF_SIZE;
}

static uint16_t bufFree() {
  return PCM_RING_BUF_SIZE - bufCount() - 1;
}

// ===== CRC8 (Dallas/Maxim, 多项式 0x31 反射) =====
static uint8_t crc8(const uint8_t* data, size_t len) {
  uint8_t crc = 0x00;
  while (len--) {
    uint8_t byte = *data++;
    for (uint8_t i = 0; i < 8; i++) {
      uint8_t mix = (crc ^ byte) & 0x01;
      crc >>= 1;
      if (mix) crc ^= 0x8C;
      byte >>= 1;
    }
  }
  return crc;
}

static uint8_t crc8Continue(const uint8_t* data, size_t len, uint8_t init) {
  uint8_t crc = init;
  while (len--) {
    uint8_t byte = *data++;
    for (uint8_t i = 0; i < 8; i++) {
      uint8_t mix = (crc ^ byte) & 0x01;
      crc >>= 1;
      if (mix) crc ^= 0x8C;
      byte >>= 1;
    }
  }
  return crc;
}

// ===== 发送响应帧 =====
static void sendAck(uint8_t ackCmd) {
  uint8_t frame[7] = {
    PCM_SYNC1, PCM_SYNC2, PCM_CMD_ACK, 0x00, 0x01, ackCmd, 0x00
  };
  frame[6] = crc8(frame + 2, 3);
  Serial.write(frame, 7);
}

static void sendNack(uint8_t nackCmd, uint8_t reason) {
  uint8_t frame[8] = {
    PCM_SYNC1, PCM_SYNC2, PCM_CMD_NACK, 0x00, 0x02, nackCmd, reason, 0x00
  };
  frame[7] = crc8(frame + 2, 4);
  Serial.write(frame, 8);
}

static void sendReady() {
  uint16_t free = bufFree();
  uint8_t frame[8] = {
    PCM_SYNC1, PCM_SYNC2, PCM_CMD_READY, 0x00, 0x02,
    (uint8_t)(free >> 8), (uint8_t)(free & 0xFF), 0x00
  };
  frame[7] = crc8(frame + 2, 4);
  Serial.write(frame, 8);
}

// ===== 16kHz Timer 中断 (必须放 RAM 中避免 Flash 缓存未命中) =====
void ICACHE_RAM_ATTR onPcmSampleTick() {
  if (playing && readIdx != writeIdx) {
    int16_t sample = ringBuf[readIdx];
    // 音量调整: 以 128 为中点进行缩放
    int16_t adjusted = ((sample - 128) * (int16_t)volume) / 255 + 128;
    if (adjusted < 0) adjusted = 0;
    if (adjusted > 255) adjusted = 255;
    analogWrite(BUZZER_PIN, (uint8_t)adjusted);
    readIdx = (readIdx + 1) % PCM_RING_BUF_SIZE;
  } else {
    // 缓冲区空或未播放 → 输出中点（静音）
    analogWrite(BUZZER_PIN, 128);
  }
}

// ===== 初始化 =====
void pcmInit() {
  pinMode(BUZZER_PIN, OUTPUT);

  // 配置硬件 PWM
  analogWriteFreq(PWM_FREQ);
  analogWriteRange(PWM_RANGE);
  analogWrite(BUZZER_PIN, 128); // 初始静音(中点)

  // 启动 16kHz 采样率定时器
  sampleTimer.attach_ms(1000.0 / PCM_SAMPLE_RATE, onPcmSampleTick);
}

// ===== 命令处理 =====
static void handleFrame(uint8_t cmd, const uint8_t* payload, uint16_t len) {
  switch (cmd) {
    case PCM_CMD_HANDSHAKE:
      sendAck(PCM_CMD_HANDSHAKE);
      break;

    case PCM_CMD_FORMAT:
      // payload: sample_rate(4 LE) + bps(1) + ch(1)
      // 上位机已传递参数，ESP8266 仅确认
      sendAck(PCM_CMD_FORMAT);
      break;

    case PCM_CMD_PLAY:
      playing = true;
      sampleTimer.attach_ms(1000.0 / PCM_SAMPLE_RATE, onPcmSampleTick);
      sendAck(PCM_CMD_PLAY);
      break;

    case PCM_CMD_STOP:
      playing = false;
      sampleTimer.detach();
      readIdx = writeIdx;   // 清空缓冲区
      sendAck(PCM_CMD_STOP);
      break;

    case PCM_CMD_DATA: {
      if (len < 2) {
        sendNack(PCM_CMD_DATA, 0x03); // payload too short
        break;
      }
      // payload: seq(2 LE) + samples[]
      // uint16_t seq = payload[0] | ((uint16_t)payload[1] << 8);
      uint16_t sampleCount = len - 2;
      for (uint16_t i = 0; i < sampleCount; i++) {
        uint16_t next = (writeIdx + 1) % PCM_RING_BUF_SIZE;
        if (next == readIdx) break;  // 缓冲区满则丢弃后续采样
        ringBuf[writeIdx] = payload[2 + i];
        writeIdx = next;
      }
      break;
    }

    case PCM_CMD_VOLUME:
      if (len >= 1) {
        volume = payload[0];
        sendAck(PCM_CMD_VOLUME);
      }
      break;

    case PCM_CMD_PING:
      sendAck(PCM_CMD_PING);
      break;

    case PCM_CMD_RESET:
      playing = false;
      readIdx = writeIdx = 0;
      sendAck(PCM_CMD_RESET);
      break;

    default:
      sendNack(cmd, 0xFF); // unknown command
      break;
  }
}

// ===== 主循环中调用: 解析串口数据 =====
void pcmProcessSerial() {
  static unsigned long lastReadyTime = 0;

  // 每 200ms 上报缓冲区状态
  if (millis() - lastReadyTime > 200) {
    sendReady();
    lastReadyTime = millis();
  }

  while (Serial.available()) {
    uint8_t b = Serial.read();

    switch (parseState) {
      case WAIT_SYNC1:
        if (b == PCM_SYNC1) parseState = WAIT_SYNC2;
        break;

      case WAIT_SYNC2:
        parseState = (b == PCM_SYNC2) ? WAIT_CMD : WAIT_SYNC1;
        break;

      case WAIT_CMD:
        rxCmd = b;
        parseState = WAIT_LEN_H;
        break;

      case WAIT_LEN_H:
        rxPayloadLen = ((uint16_t)b) << 8;
        parseState = WAIT_LEN_L;
        break;

      case WAIT_LEN_L:
        rxPayloadLen |= b;
        rxPayloadIdx = 0;
        if (rxPayloadLen > sizeof(rxPayloadBuf)) {
          sendNack(rxCmd, PCM_ERR_PAYLOAD_TOO_LARGE);
          parseState = WAIT_SYNC1;
        } else if (rxPayloadLen > 0) {
          parseState = WAIT_PAYLOAD;
        } else {
          parseState = WAIT_CRC;
        }
        break;

      case WAIT_PAYLOAD:
        rxPayloadBuf[rxPayloadIdx++] = b;
        if (rxPayloadIdx >= rxPayloadLen) parseState = WAIT_CRC;
        break;

      case WAIT_CRC: {
        // 计算 CRC over CMD + LEN_H + LEN_L + PAYLOAD
        uint8_t header[] = {
          rxCmd,
          (uint8_t)(rxPayloadLen >> 8),
          (uint8_t)(rxPayloadLen & 0xFF)
        };
        uint8_t expected = crc8(header, 3);
        if (rxPayloadLen > 0) {
          expected = crc8Continue(rxPayloadBuf, rxPayloadLen, expected);
        }

        if (b != expected) {
          sendNack(rxCmd, PCM_ERR_CRC_MISMATCH);
        } else {
          handleFrame(rxCmd, rxPayloadBuf, rxPayloadLen);
        }
        parseState = WAIT_SYNC1;
        break;
      }
    }
  }
}

bool pcmIsPlaying() {
  return playing;
}

void pcmSetVolume(uint8_t vol) {
  volume = vol;
}
