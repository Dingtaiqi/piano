#ifndef DISPLAY_H
#define DISPLAY_H

#include <Arduino.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Wire.h>
#include "config.h"

// 显示屏对象
extern Adafruit_SSD1306 display;

// 熄屏相关变量
extern int screenOffMode;
extern unsigned long lastActivityTime;
extern bool screenOn;

// 函数声明
void initDisplay();
void drawPianoKeyboard(int* pressedKeys, int keyCount);
void displayMultipleKeys(int* keys, int keyCount);
void showStartupScreen();
void showNetworkInfo();
void showTeachingMode(int nextNote, bool correct, String message);
void updateScreenActivity();
void checkScreenTimeout();
void turnOffScreen();
void turnOnScreen();

#endif