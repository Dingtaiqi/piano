#include "pcm_audio.h"
#include "config.h"
#include "music.h"

// ===== 协议解析状态机 =====
enum ParseState { WAIT_SYNC1, WAIT_SYNC2, WAIT_CMD, WAIT_LEN_H, WAIT_LEN_L, WAIT_PAYLOAD, WAIT_CRC };
static ParseState parseState = WAIT_SYNC1;
static uint8_t rxCmd = 0;
static uint16_t rxPayloadLen = 0;
static uint16_t rxPayloadIdx = 0;
static uint8_t rxPayloadBuf[600]; // 32 name + 2 count + 512 notes + margin

// ===== CRC8 =====
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

// ===== 发送响应 =====
static void sendAck(uint8_t ackCmd) {
  uint8_t frame[] = {PCM_SYNC1, PCM_SYNC2, PCM_CMD_ACK, 0x00, 0x01, ackCmd, 0x00};
  frame[6] = crc8(frame + 2, 3);
  Serial.write(frame, 7);
}

static void sendNack(uint8_t nackCmd, uint8_t reason) {
  uint8_t frame[] = {PCM_SYNC1, PCM_SYNC2, PCM_CMD_NACK, 0x00, 0x02, nackCmd, reason, 0x00};
  frame[7] = crc8(frame + 2, 4);
  Serial.write(frame, 8);
}

// ===== 命令处理 =====
static void handleFrame(uint8_t cmd, const uint8_t* payload, uint16_t len) {
  switch (cmd) {
    case PCM_CMD_MELODY_SEND:
      if (len < 34) { sendNack(cmd, 0x03); break; }
      {
        // payload: name[32] + count(u16) + notes[...]
        char name[33];
        memcpy(name, payload, 32);
        name[32] = '\0';

        uint16_t count = ((uint16_t)payload[32] << 8) | payload[33];
        if (count > PCM_MAX_NOTES) count = PCM_MAX_NOTES;
        if (len < (uint16_t)(34 + count)) { sendNack(cmd, 0x03); break; }

        setUploadedMelody((int8_t*)&payload[34], count, name);
        sendAck(cmd);
      }
      break;

    case PCM_CMD_MELODY_PLAY:
      triggerUploadedPlayback();
      sendAck(cmd);
      break;

    default:
      sendNack(cmd, 0xFF);
      break;
  }
}

// ===== 初始化 =====
void pcmInit() {
  // No hardware init needed for melody protocol
}

// ===== 主循环中调用 =====
void pcmProcessSerial() {
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
        rxCmd = b; parseState = WAIT_LEN_H;
        break;
      case WAIT_LEN_H:
        rxPayloadLen = ((uint16_t)b) << 8; parseState = WAIT_LEN_L;
        break;
      case WAIT_LEN_L:
        rxPayloadLen |= b; rxPayloadIdx = 0;
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
        // CRC over CMD + LEN_H + LEN_L + PAYLOAD
        uint8_t crcData[3 + 1024];
        crcData[0] = rxCmd;
        crcData[1] = (uint8_t)(rxPayloadLen >> 8);
        crcData[2] = (uint8_t)(rxPayloadLen & 0xFF);
        for (uint16_t i = 0; i < rxPayloadLen && i < 1024; i++) {
          crcData[3 + i] = rxPayloadBuf[i];
        }
        uint8_t expected = crc8(crcData, 3 + rxPayloadLen);
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
