#ifndef NETWORK_H
#define NETWORK_H

#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>
#include "config.h"

// 网络相关变量
extern AsyncWebServer server;
extern bool networkMode;
extern bool wifiConnected;

// Web命令队列
extern volatile int webCommand;
extern volatile bool webCommandPending;

// 教学模式变量
extern bool teachingMode;
extern int currentNoteIndex;
extern String teachingStatus;

// 自动播放变量
extern bool autoPlayMode;
extern int autoPlayIndex;
extern unsigned long lastAutoPlayTime;
extern int autoPlayInterval;

// 函数声明
void initNetwork();
void connectToWiFi(const char* ssid, const char* password);
void setupWebServer();
String generateMainPage();
String getAPIP();
void processWebCommands();

#endif