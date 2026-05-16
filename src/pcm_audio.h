#ifndef PCM_AUDIO_H
#define PCM_AUDIO_H

#include <Arduino.h>

// PCM 音频参数
#define PCM_SAMPLE_RATE     16000
#define PWM_FREQ            62500    // 62.5kHz, 高于人耳听觉范围
#define PWM_RANGE           255      // 8-bit 分辨率
#define PCM_RING_BUF_SIZE   2048     // 环形缓冲区: ~128ms 缓冲

// 协议常量
#define PCM_SYNC1     0xAA
#define PCM_SYNC2     0x55
#define PCM_HEADSIZE  5              // SYNC1+SYNC2+CMD+LEN_H+LEN_L = 5

// Host → ESP8266 命令
#define PCM_CMD_HANDSHAKE  0x01
#define PCM_CMD_FORMAT     0x02
#define PCM_CMD_PLAY       0x03
#define PCM_CMD_STOP       0x04
#define PCM_CMD_DATA       0x05
#define PCM_CMD_VOLUME     0x06
#define PCM_CMD_PING       0x07
#define PCM_CMD_RESET      0x08

// ESP8266 → Host 命令
#define PCM_CMD_ACK        0x80
#define PCM_CMD_NACK       0x81
#define PCM_CMD_READY      0x82
#define PCM_CMD_ERROR      0x83

// 错误码
#define PCM_ERR_PAYLOAD_TOO_LARGE  0x01
#define PCM_ERR_CRC_MISMATCH       0x02

// 函数声明
void pcmInit();
void pcmProcessSerial();
bool pcmIsPlaying();
void pcmSetVolume(uint8_t vol);

#endif
