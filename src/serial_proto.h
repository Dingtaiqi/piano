#ifndef SERIAL_PROTO_H
#define SERIAL_PROTO_H

#include <Arduino.h>

// 协议常量
#define SERIAL_SYNC1     0xAA
#define SERIAL_SYNC2     0x55

// Host → ESP8266
#define CMD_MELODY_SEND  0x10   // payload: name[32] + count(u16) + notes[]
#define CMD_MELODY_PLAY  0x11   // no payload
#define CMD_MELODY_TEACH 0x12   // no payload, start teaching mode
#define CMD_MELODY_STOP  0x13   // no payload, stop teaching/playback

// ESP8266 → Host
#define CMD_ACK          0x80
#define CMD_NACK         0x81
#define CMD_TEACH_EVENT  0x82   // payload: eventType(1) + noteIndex(u16) + total(u16) + noteValue(1)

// 教学事件类型
#define TEACH_SHOW_NOTE   0x01
#define TEACH_CORRECT     0x02
#define TEACH_WRONG       0x03
#define TEACH_COMPLETE    0x04

// 错误码
#define ERR_PAYLOAD_TOO_LARGE  0x01
#define ERR_CRC_MISMATCH       0x02

#define MAX_NOTES          512
#define MAX_MELODY_NAME    32

void serialProtoInit();
void serialProtoProcess();
void sendTeachEvent(uint8_t eventType, uint16_t noteIndex, uint16_t totalNotes, uint8_t noteValue);
void startSerialTeaching();

#endif
