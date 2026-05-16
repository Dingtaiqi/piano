#include "touch.h"
#include <math.h>

// 触摸相关变量
SC12B touchPannel;
boolean iftouch = false;
uint16_t currentKeys = 0;
uint16_t previousKeys = 0;
unsigned long lastKeyTime = 0;
int touchSensitivity = DEFAULT_TOUCH_SENSITIVITY;

// 多键检测缓冲区
uint16_t keyBuffer[5];
int bufferIndex = 0;
unsigned long lastSampleTime = 0;

void initTouch() {
  pinMode(TOUCH_INTERRUPT_PIN, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(TOUCH_INTERRUPT_PIN), checkkey, CHANGE);
  touchPannel.begin();
  touchPannel.init();
  applyTouchSensitivity();
}

/**
 * 触摸中断服务程序
 */
void IRAM_ATTR checkkey() {
  iftouch = true;
}

// 应用触摸灵敏度设置到SC12B芯片
void applyTouchSensitivity() {
  Sensitivity sensitivityLevel;
  switch(touchSensitivity) {
    case 0: sensitivityLevel = LEVEL0; break;
    case 1: sensitivityLevel = LEVEL1; break;
    case 2: sensitivityLevel = LEVEL2; break;
    case 3: sensitivityLevel = LEVEL3; break;
    case 4: sensitivityLevel = LEVEL4; break;
    case 5: sensitivityLevel = LEVEL5; break;
    case 6: sensitivityLevel = LEVEL6; break;
    case 7: sensitivityLevel = LEVEL7; break;
    case 8: sensitivityLevel = LEVEL8; break;
    case 9: sensitivityLevel = LEVEL9; break;
    case 10: sensitivityLevel = LEVEL10; break;
    case 11: sensitivityLevel = LEVEL11; break;
    case 12: sensitivityLevel = LEVEL12; break;
    case 13: sensitivityLevel = LEVEL13; break;
    case 14: sensitivityLevel = LEVEL14; break;
    case 15: sensitivityLevel = LEVEL15; break;
    default: sensitivityLevel = LEVEL0; break;
  }
  
  touchPannel.writeRegister(REG_Senset0, sensitivityLevel);
  touchPannel.writeRegister(REG_SensetCOM, sensitivityLevel);
}

/**
 * 多键检测函数 - 多触控实现的核心算法
 */
uint16_t detectMultipleKeys() {
  uint16_t combinedKeys = 0;
  
  for (int i = 0; i < 5; i++) {
    uint16_t keyValue = touchPannel.getKeyValue();
    combinedKeys |= keyValue;
    delay(1);
  }
  
  return combinedKeys;
}

/**
 * 键值解析函数 - 多触控数据解码的核心算法
 */
void parseKeys(uint16_t keyValue, int* pressedKeys, int* keyCount) {
  *keyCount = 0;
  
  if (keyValue == 0) return;
  // 标准多键检测
  for (int i = 4; i < 16; i++) {
    if (keyValue & (1 << i)) {
      int keyIndex = i - 3;
      
      if (keyIndex >= 1 && keyIndex <= 12) {
        pressedKeys[*keyCount] = keyIndex;
        (*keyCount)++;
      }
    }
  }
}