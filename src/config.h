#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>

// 硬件引脚定义
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
#define OLED_RESET -1
#define SCREEN_ADDRESS 0x3C
#define TOUCH_INTERRUPT_PIN 14
#define BUZZER_PIN 12

// 触摸检测参数
#define KEY_DEBOUNCE_TIME 20   // 防抖时间(ms)
#define SAMPLE_INTERVAL 5      // 采样间隔(ms)

// 网络配置
#define AP_SSID "EDA-Piano"
#define AP_PASSWORD ""
#define WEB_SERVER_PORT 80

// EEPROM配置
#define EEPROM_SIZE 512
#define CONFIG_START_ADDR 0

// 音频参数
#define DEFAULT_NOTE_DURATION 500  // 默认音符持续时间(ms)
#define DEFAULT_OCTAVE_SHIFT 0     // 默认八度偏移
#define DEFAULT_TOUCH_SENSITIVITY 0 // 默认触摸灵敏度

// 混音参数
#define MIX_DURATION 1000          // 混音播放时长(ms)
#define MIX_UPDATE_INTERVAL 100    // 混音更新间隔(微秒)

// 熄屏设置
#define SCREEN_OFF_NONE 0          // 无熄屏
#define SCREEN_OFF_10SEC 1         // 10秒熄屏
#define SCREEN_OFF_1MIN 2          // 1分钟熄屏
#define SCREEN_OFF_5MIN 3          // 5分钟熄屏
#define SCREEN_OFF_15MIN 4         // 15分钟熄屏
#define SCREEN_OFF_30MIN 5         // 30分钟熄屏

#endif