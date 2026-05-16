#include "display.h"
#include "audio.h"
#include "touch.h"
#include "network.h"

// 显示屏对象
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// 熄屏相关变量
int screenOffMode = SCREEN_OFF_NONE;  // 默认不熄屏
unsigned long lastActivityTime = 0;
bool screenOn = true;

void initDisplay() {
  if(!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println("not found oled ssd1306!");
  }
  lastActivityTime = millis();
  screenOn = true;
}

void showStartupScreen() {
  updateScreenActivity();
  display.clearDisplay();
  display.setRotation(2);
  display.setTextSize(2);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0,0);
  display.println("EDA-Piano");
  display.setTextSize(1); 
  display.println("v2.0 Network");
  display.println("Initializing...");
  display.display();
}

void showNetworkInfo() {
  updateScreenActivity();
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(0,0);
  display.println("EDA-Piano v2.0");
  display.println("Touch Mode Ready");
  display.println("");
  display.print("Web: ");
  display.println(getAPIP());
  display.print("Duration: ");
  display.print(noteDuration);
  display.println("ms");
  display.print("Octave: ");
  display.println(octaveShift);
  display.display();
}

/**
 * 绘制钢琴键盘函数
 */
void drawPianoKeyboard(int* pressedKeys, int keyCount) {
  updateScreenActivity();
  display.clearDisplay();
  display.setRotation(2);
  
  // 设置文字显示参数
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  
  // 根据按键数量显示不同的信息
  if (keyCount == 0) {
    display.print("Oct:");
    if (octaveShift > 0) {
      display.print("+");
    }
    display.print(octaveShift);
    display.print(" Sens:L");
    display.println(touchSensitivity);
  } else {
    display.print("Key");
    display.print(": ");
    
    for (int i = 0; i < keyCount; i++) {
      display.print(keyString[pressedKeys[i]]);
      if (i < keyCount - 1) display.print(",");
    }
  }
  
  // 键盘绘制参数
  int keyboardY = 10;
  int whiteKeyHeight = 22;
  int blackKeyHeight = 14;
  int keyWidth = 128 / 7;
  
  // 创建按键状态映射数组
  bool keyPressed[13] = {false};
  
  for (int i = 0; i < keyCount; i++) {
    if (pressedKeys[i] >= 1 && pressedKeys[i] <= 12) {
      keyPressed[pressedKeys[i]] = true;
    }
  }
  
  // 白键和黑键映射
  int whiteKeys[] = {1, 3, 5, 6, 8, 10, 12};
  int blackKeys[] = {2, 4, 7, 9, 11};
  int blackKeyPositions[] = {0, 1, 3, 4, 5};
  
  // 绘制白键
  for (int i = 0; i < 7; i++) {
    int keyX = i * keyWidth;
    int keyNum = whiteKeys[i];
    
    display.drawRect(keyX, keyboardY, keyWidth, whiteKeyHeight, SSD1306_WHITE);
    
    if (keyPressed[keyNum]) {
      display.fillRect(keyX + 1, keyboardY + 1, keyWidth - 2, whiteKeyHeight - 2, SSD1306_WHITE);
    }
    
    display.setTextSize(1);
    display.setTextColor(keyPressed[keyNum] ? SSD1306_BLACK : SSD1306_WHITE);
    display.setCursor(keyX + keyWidth/2 - 3, keyboardY + whiteKeyHeight - 8);
    display.print(keyString[keyNum]);
  }
  
  // 绘制黑键
  for (int i = 0; i < 5; i++) {
    int whiteKeyIndex = blackKeyPositions[i];
    int keyX = whiteKeyIndex * keyWidth + keyWidth * 2/3;
    int keyNum = blackKeys[i];
    int blackKeyWidth = keyWidth * 2/3;
    
    if (keyPressed[keyNum]) {
      display.fillRect(keyX, keyboardY, blackKeyWidth, blackKeyHeight, SSD1306_WHITE);
      display.drawRect(keyX, keyboardY, blackKeyWidth, blackKeyHeight, SSD1306_WHITE);
    } else {
      display.fillRect(keyX, keyboardY, blackKeyWidth, blackKeyHeight, SSD1306_WHITE);
      display.drawRect(keyX + 1, keyboardY + 1, blackKeyWidth - 2, blackKeyHeight - 2, SSD1306_BLACK);
    }
    
    display.setTextSize(1);
    display.setTextColor(keyPressed[keyNum] ? SSD1306_BLACK : SSD1306_WHITE);
    display.setCursor(keyX + blackKeyWidth/2 - 4, keyboardY + blackKeyHeight - 8);
    display.print(keyString[keyNum].charAt(0));
  }
  
  display.display();
}

void displayMultipleKeys(int* keys, int keyCount) {
  drawPianoKeyboard(keys, keyCount);
}

void showTeachingMode(int nextNote, bool correct, String message) {
  updateScreenActivity();
  display.clearDisplay();
  display.setRotation(2);
  
  // 设置文字显示参数
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  
  // 显示反馈信息而不是"Key:"
  if (message.length() > 0) {
    if (message == "Good!") {
      display.print("Good!");
    } else if (message == "Error!") {
      display.print("Error!");
    } else {
      display.print(message);
    }
  } else {
    display.print("Teaching Mode");
  }
  
  // 键盘绘制参数
  int keyboardY = 10;
  int whiteKeyHeight = 22;
  int blackKeyHeight = 14;
  int keyWidth = 128 / 7;
  
  // 创建按键状态映射数组
  bool keyPressed[13] = {false};
  
  // 高亮显示需要按的键
  if (nextNote > 0 && nextNote <= 12) {
    keyPressed[nextNote] = true;
  }
  
  // 白键和黑键映射
  int whiteKeys[] = {1, 3, 5, 6, 8, 10, 12};
  int blackKeys[] = {2, 4, 7, 9, 11};
  int blackKeyPositions[] = {0, 1, 3, 4, 5};
  
  // 绘制白键
  for (int i = 0; i < 7; i++) {
    int keyX = i * keyWidth;
    int keyNum = whiteKeys[i];
    
    display.drawRect(keyX, keyboardY, keyWidth, whiteKeyHeight, SSD1306_WHITE);
    
    if (keyPressed[keyNum]) {
      display.fillRect(keyX + 1, keyboardY + 1, keyWidth - 2, whiteKeyHeight - 2, SSD1306_WHITE);
    }
    
    display.setTextSize(1);
    display.setTextColor(keyPressed[keyNum] ? SSD1306_BLACK : SSD1306_WHITE);
    display.setCursor(keyX + keyWidth/2 - 3, keyboardY + whiteKeyHeight - 8);
    display.print(keyString[keyNum]);
  }
  
  // 绘制黑键
  for (int i = 0; i < 5; i++) {
    int whiteKeyIndex = blackKeyPositions[i];
    int keyX = whiteKeyIndex * keyWidth + keyWidth * 2/3;
    int keyNum = blackKeys[i];
    int blackKeyWidth = keyWidth * 2/3;
    
    if (keyPressed[keyNum]) {
      display.fillRect(keyX, keyboardY, blackKeyWidth, blackKeyHeight, SSD1306_WHITE);
      display.drawRect(keyX, keyboardY, blackKeyWidth, blackKeyHeight, SSD1306_WHITE);
    } else {
      display.fillRect(keyX, keyboardY, blackKeyWidth, blackKeyHeight, SSD1306_WHITE);
      display.drawRect(keyX + 1, keyboardY + 1, blackKeyWidth - 2, blackKeyHeight - 2, SSD1306_BLACK);
    }
    
    display.setTextSize(1);
    display.setTextColor(keyPressed[keyNum] ? SSD1306_BLACK : SSD1306_WHITE);
    display.setCursor(keyX + blackKeyWidth/2 - 4, keyboardY + blackKeyHeight - 8);
    display.print(keyString[keyNum].charAt(0));
  }
  
  display.display();
}
void updateScreenActivity() {
  lastActivityTime = millis();
  if (!screenOn) {
    turnOnScreen();
  }
}

void checkScreenTimeout() {
  if (screenOffMode == SCREEN_OFF_NONE || !screenOn) {
    return;
  }
  
  unsigned long currentTime = millis();
  unsigned long timeout = 0;
  
  switch (screenOffMode) {
    case SCREEN_OFF_10SEC:
      timeout = 10 * 1000UL;      // 10秒
      break;
    case SCREEN_OFF_1MIN:
      timeout = 1 * 60 * 1000UL;  // 1分钟
      break;
    case SCREEN_OFF_5MIN:
      timeout = 5 * 60 * 1000UL;  // 5分钟
      break;
    case SCREEN_OFF_15MIN:
      timeout = 15 * 60 * 1000UL; // 15分钟
      break;
    case SCREEN_OFF_30MIN:
      timeout = 30 * 60 * 1000UL; // 30分钟
      break;
    default:
      return;
  }
  
  if (currentTime - lastActivityTime >= timeout) {
    turnOffScreen();
  }
}

void turnOffScreen() {
  if (screenOn) {
    display.clearDisplay();
    display.display();
    display.ssd1306_command(SSD1306_DISPLAYOFF);
    screenOn = false;
  }
}

void turnOnScreen() {
  if (!screenOn) {
    display.ssd1306_command(SSD1306_DISPLAYON);
    screenOn = true;
    // 重新显示当前界面
    showNetworkInfo();
  }
}