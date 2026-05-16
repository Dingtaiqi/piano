#ifndef TOUCH_H
#define TOUCH_H

#include <Arduino.h>
#include "SC12B.h"
#include "config.h"

// 触摸相关变量
extern SC12B touchPannel;
extern boolean iftouch;
extern uint16_t currentKeys;
extern uint16_t previousKeys;
extern unsigned long lastKeyTime;
extern int touchSensitivity;

// 多键检测缓冲区
extern uint16_t keyBuffer[5];
extern int bufferIndex;
extern unsigned long lastSampleTime;

// 函数声明
void initTouch();
void IRAM_ATTR checkkey();
void applyTouchSensitivity();
uint16_t detectMultipleKeys();
void parseKeys(uint16_t keyValue, int* pressedKeys, int* keyCount);

#endif