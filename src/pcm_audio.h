#ifndef PCM_AUDIO_H
#define PCM_AUDIO_H

#include <Arduino.h>

// 协议常量
#define PCM_SYNC1     0xAA
#define PCM_SYNC2     0x55

// Host → ESP8266
#define PCM_CMD_MELODY_SEND  0x10   // payload: name[32] + count(u16) + notes[]
#define PCM_CMD_MELODY_PLAY  0x11   // no payload

// ESP8266 → Host
#define PCM_CMD_ACK        0x80
#define PCM_CMD_NACK       0x81

// 错误码
#define PCM_ERR_PAYLOAD_TOO_LARGE  0x01
#define PCM_ERR_CRC_MISMATCH       0x02

#define PCM_MAX_NOTES  512
#define PCM_MAX_MELODY_NAME  32

void pcmInit();
void pcmProcessSerial();

#endif
