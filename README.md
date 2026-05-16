# EDA-Piano 电子钢琴项目

一个基于 ESP8266 的智能电子钢琴系统，支持触摸控制、OLED 显示、WiFi 网络控制和音乐教学功能。

## 项目概述

EDA-Piano 是一个完整的嵌入式音频系统，集成了多点触摸检测、音频播放、显示控制和网络服务功能。系统采用模块化设计，每个功能模块独立开发，便于维护和扩展。

## 硬件配置

- **主控芯片**: ESP8266 (NodeMCU v2)
- **显示屏**: 128x32 OLED (SSD1306)
- **触摸芯片**: SC12B (12 通道电容触摸)
- **音频输出**: 蜂鸣器 (GPIO12)
- **通信接口**: I2C (显示屏), I2C (触摸芯片)

## 核心功能模块

### 1. audio.h/.cpp - 音频播放和混音处理

**主要功能:**

- 基础音频频率生成 (12 个半音)
- 八度调节 (-2 到+2 八度)
- 多音符混音播放
- 音符持续时间控制

**核心特性:**

- 支持 C4 到 B4 的 12 个基础音符
- 实时混音算法，支持多键同时按下
- 可调节音符持续时间 (100-2000ms)
- PWM 音频输出，音质清晰

**关键变量:**

```cpp
int noteDuration;           // 音符持续时间
int octaveShift;           // 八度偏移
volatile bool isMixPlaying; // 混音播放状态
volatile int mixKeys[12];   // 混音按键缓冲区
```

**核心代码段:**

音频频率计算：

```cpp
// 获取调整八度后的频率
int getNoteFrequency(int noteIndex) {
  if (noteIndex < 1 || noteIndex > 12) return 0;

  float freq = baseFrequencies[noteIndex];
  // 八度调节：每个八度频率翻倍或减半
  for (int i = 0; i < abs(octaveShift); i++) {
    if (octaveShift > 0) {
      freq *= 2.0;  // 升高八度
    } else if (octaveShift < 0) {
      freq /= 2.0;  // 降低八度
    }
  }
  return (int)freq;
}
```

多音符播放控制：

```cpp
void playMultipleNotes(int* keys, int keyCount) {
  // 停止之前的播放
  isMixPlaying = false;
  noTone(BUZZER_PIN);

  if (keyCount == 0) return;

  if (keyCount == 1) {
    // 单音符使用tone函数，使用统一的音长设置
    tone(BUZZER_PIN, getNoteFrequency(keys[0]), noteDuration);
  } else {
    // 多音符使用简化混音
    mixKeyCount = keyCount;
    mixStartTime = millis();
    lastMixUpdate = micros();

    // 复制按键数组
    for (int i = 0; i < keyCount; i++) {
      mixKeys[i] = keys[i];
    }

    isMixPlaying = true;
    updateMixedTone();  // 立即开始播放
  }
}
```

混音播放算法：

```cpp
void updateMixedTone() {
  if (!isMixPlaying || mixKeyCount == 0) return;

  // 计算混合频率（简单平均）
  float avgFrequency = 0;
  for (int i = 0; i < mixKeyCount; i++) {
    avgFrequency += getNoteFrequency(mixKeys[i]);
  }
  avgFrequency /= mixKeyCount;

  // 使用tone函数播放平均频率
  tone(BUZZER_PIN, (int)avgFrequency, 100);
}
```

基础音频频率数组：

```cpp
// 基础音频频率（第4八度）
int baseFrequencies[] = {
  0,   // 占位，索引从1开始
  262, // 1 do (C4)
  277, // 2 升do (C#4)
  294, // 3 re (D4)
  311, // 4 升re (D#4)
  330, // 5 mi (E4)
  349, // 6 fa (F4)
  370, // 7 升fa (F#4)
  392, // 8 so (G4)
  415, // 9 升so (G#4)
  440, // 10 la (A4)
  466, // 11 升la (A#4)
  494  // 12 si (B4)
};
```

### 2. display.h/.cpp - OLED 显示控制

**主要功能:**

- 钢琴键盘可视化显示
- 网络状态信息显示
- 教学模式界面
- 智能熄屏管理

**显示界面:**

- **钢琴键盘**: 7 个白键 + 5 个黑键的完整显示
- **按键反馈**: 实时高亮显示按下的键
- **状态信息**: 八度、灵敏度、音符时长显示
- **教学模式**: 引导式学习界面

**熄屏功能:**

- 支持 5 种熄屏时间设置 (10 秒-30 分钟)
- 触摸自动唤醒
- 活动时间自动跟踪

**核心代码段:**

钢琴键盘绘制算法：

```cpp
void drawPianoKeyboard(int* pressedKeys, int keyCount) {
  display.clearDisplay();

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
  }

  // 绘制黑键
  for (int i = 0; i < 5; i++) {
    int whiteKeyIndex = blackKeyPositions[i];
    int keyX = whiteKeyIndex * keyWidth + keyWidth * 2/3;
    int keyNum = blackKeys[i];

    if (keyPressed[keyNum]) {
      display.fillRect(keyX, keyboardY, blackKeyWidth, blackKeyHeight, SSD1306_WHITE);
    } else {
      display.fillRect(keyX, keyboardY, blackKeyWidth, blackKeyHeight, SSD1306_WHITE);
      display.drawRect(keyX + 1, keyboardY + 1, blackKeyWidth - 2, blackKeyHeight - 2, SSD1306_BLACK);
    }
  }

  display.display();
}
```

熄屏管理：

```cpp
void checkScreenTimeout() {
  if (screenOffMode == SCREEN_OFF_NONE || !screenOn) return;

  unsigned long currentTime = millis();
  unsigned long timeout = 0;

  switch (screenOffMode) {
    case SCREEN_OFF_10SEC:  timeout = 10 * 1000UL; break;
    case SCREEN_OFF_1MIN:   timeout = 1 * 60 * 1000UL; break;
    case SCREEN_OFF_5MIN:   timeout = 5 * 60 * 1000UL; break;
    case SCREEN_OFF_15MIN:  timeout = 15 * 60 * 1000UL; break;
    case SCREEN_OFF_30MIN:  timeout = 30 * 60 * 1000UL; break;
  }

  if (currentTime - lastActivityTime >= timeout) {
    turnOffScreen();
  }
}
```

### 3. touch.h/.cpp - 触摸检测和多键处理

**主要功能:**

- 12 通道电容触摸检测
- 多点触摸支持
- 触摸灵敏度调节
- 防抖处理

**多触控算法:**

- 采用 5 次采样合并算法提高检测精度
- 位运算解析多键同时按下
- 16 级灵敏度调节 (LEVEL0-LEVEL15)
- 中断驱动 + 轮询双重检测机制

**关键算法:**

多键检测（5 次采样合并）：

```cpp
uint16_t detectMultipleKeys() {
  uint16_t combinedKeys = 0;

  for (int i = 0; i < 5; i++) {
    uint16_t keyValue = touchPannel.getKeyValue();
    combinedKeys |= keyValue;  // 位运算合并多次采样
    delay(1);
  }

  return combinedKeys;
}
```

键值解析（位运算解码）：

```cpp
void parseKeys(uint16_t keyValue, int* pressedKeys, int* keyCount) {
  *keyCount = 0;

  if (keyValue == 0) return;

  // 标准多键检测 - 位4到位15对应键1到键12
  for (int i = 4; i < 16; i++) {
    if (keyValue & (1 << i)) {  // 位运算检测
      int keyIndex = i - 3;

      if (keyIndex >= 1 && keyIndex <= 12) {
        pressedKeys[*keyCount] = keyIndex;
        (*keyCount)++;
      }
    }
  }
}
```

触摸中断处理：

```cpp
void IRAM_ATTR checkkey() {
  iftouch = true;  // 中断标志位
}

void initTouch() {
  pinMode(TOUCH_INTERRUPT_PIN, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(TOUCH_INTERRUPT_PIN), checkkey, CHANGE);
  touchPannel.begin();
  touchPannel.init();
  applyTouchSensitivity();
}
```

### 4. network.h/.cpp - WiFi 和 Web 服务器

**主要功能:**

- WiFi 热点模式 (AP 模式)
- Web 服务器 (端口 80)
- RESTful API 接口
- 实时参数调节

**Web 功能:**

- **虚拟钢琴**: 网页端可视化钢琴键盘
- **参数控制**: 音符时长、八度、灵敏度在线调节
- **歌曲播放**: 预置歌曲自动播放
- **教学模式**: 网页端启动学习模式

**API 接口设计:**

```
GET /play/{1-12}        - 播放单个音符
GET /chord/{keys}       - 播放和弦
GET /song/play?id={id}  - 播放歌曲
GET /teaching/start?id={id} - 启动教学
GET /set/duration?value={ms} - 设置音符时长
GET /set/octave?value={-2~2} - 设置八度
GET /set/sensitivity?value={0~15} - 设置触摸灵敏度
GET /status             - 获取系统状态
```

**Web 服务器核心实现:**

```cpp
void setupWebServer() {
  // 主页面 - 响应式钢琴界面
  server.on("/", HTTP_GET, [](AsyncWebServerRequest *request){
    request->send(200, "text/html", generateMainPage());
  });

  // 动态API路由 - 播放音符
  for(int i = 1; i <= 12; i++) {
    String path = "/play/" + String(i);
    server.on(path.c_str(), HTTP_GET, [i](AsyncWebServerRequest *request){
      webCommand = i;
      webCommandPending = true;
      request->send(200, "text/plain", "OK");
    });
  }

  // 参数设置API - 支持实时调节
  server.on("/set/duration", HTTP_GET, [](AsyncWebServerRequest *request){
    if (request->hasParam("value")) {
      int dur = request->getParam("value")->value().toInt();
      if (dur >= 100 && dur <= 2000) {
        noteDuration = dur;
        request->send(200, "text/plain", "OK");
      } else {
        request->send(400, "text/plain", "Invalid duration");
      }
    }
  });

  server.begin();
}
```

**命令队列处理机制:**

```cpp
// Web命令队列变量
volatile int webCommand = 0;
volatile bool webCommandPending = false;

void processWebCommands() {
  if (!webCommandPending) return;

  webCommandPending = false;

  if (webCommand >= 1 && webCommand <= 12) {
    // 播放单个音符
    int keys[] = {webCommand};
    playMultipleNotes(keys, 1);
  }
  else if (webCommand == 201) {
    // C大调和弦 [1,5,8]
    int keys[] = {1, 5, 8};
    playMultipleNotes(keys, 3);
  }
  else if (webCommand == 300) {
    // 启动自动播放模式
    autoPlayMode = true;
    autoPlayIndex = -1;
    lastAutoPlayTime = millis() - autoPlayInterval;
  }

  webCommand = 0;
}
```

### 5. music.h/.cpp - 曲谱数据和播放控制

**主要功能:**

- 预置歌曲曲谱存储
- 自动播放控制
- 教学模式支持

**内置歌曲:**

- **一闪一闪亮晶晶**: 42 个音符的完整曲谱
- **两只老虎**: 32 个音符的经典儿歌

**播放模式:**

- **自动播放**: 按曲谱顺序自动播放
- **教学模式**: 逐个音符引导学习
- **实时反馈**: 正确/错误提示

**曲谱数据结构:**

```cpp
// 一闪一闪亮晶晶曲谱 (C大调)
int twinkleMelody[] = {
  1, 1, 5, 5, 6, 6, 5, 0,    // 一闪一闪亮晶晶
  4, 4, 3, 3, 2, 2, 1, 0,    // 满天都是小星星
  5, 5, 4, 4, 3, 3, 2, 0,    // 挂在天空放光明
  5, 5, 4, 4, 3, 3, 2, 0,    // 好像许多小眼睛
  1, 1, 5, 5, 6, 6, 5, 0,    // 一闪一闪亮晶晶
  4, 4, 3, 3, 2, 2, 1        // 满天都是小星星
};

// 两只老虎曲谱
int tigerMelody[] = {
  1, 2, 3, 1, 1, 2, 3, 1,    // 两只老虎，两只老虎
  3, 4, 5, 0, 3, 4, 5, 0,    // 跑得快，跑得快
  5, 6, 5, 4, 3, 1, 0,       // 一只没有眼睛
  5, 6, 5, 4, 3, 1, 0,       // 一只没有尾巴
  1, 5, 1, 0, 1, 5, 1        // 真奇怪，真奇怪
};
```

**歌曲管理系统:**

```cpp
// 歌曲信息结构体
struct Song {
  String name;
  int* melody;
  int length;
  int tempo;  // BPM
};

// 歌曲数据库
Song songs[] = {
  {"一闪一闪亮晶晶", twinkleMelody, 42, 120},
  {"两只老虎", tigerMelody, 32, 100}
};

// 当前播放状态
int currentSongId = 0;
bool autoPlayMode = false;
int autoPlayIndex = 0;
unsigned long lastAutoPlayTime = 0;
int autoPlayInterval = 600;  // 默认间隔600ms

// 获取当前歌曲信息
int* getCurrentMelody() {
  return songs[currentSongId].melody;
}

int getCurrentMelodyCount() {
  return songs[currentSongId].length;
}

void setCurrentSong(int songId) {
  if (songId >= 0 && songId < 2) {
    currentSongId = songId;
    // 根据歌曲调整播放速度
    autoPlayInterval = 60000 / songs[songId].tempo;  // 转换BPM到毫秒
  }
}
```

### 6. SC12B.h/.cpp - 触摸芯片驱动

**主要功能:**

- SC12B 芯片底层驱动
- I2C 通信协议实现
- 寄存器配置管理

**技术特性:**

- 12 通道电容触摸检测
- 16 级灵敏度调节
- I2C 地址: 0x40
- 支持同时多键检测

**寄存器配置:**

```cpp
#define REG_Senset0   0x00  // 灵敏度设置
#define REG_SensetCOM 0x01  // 公共灵敏度
#define REG_OUTPUT1   0x08  // 输出寄存器1
#define REG_OUTPUT2   0x09  // 输出寄存器2
```

<div style="background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%); border: 2px solid #4a90e2; border-radius: 12px; padding: 20px; margin: 20px 0; box-shadow: 0 4px 12px rgba(74, 144, 226, 0.15);">
<div style="font-size: 1.5em; font-weight: bold; margin-bottom: 15px; color: #2c3e50; display: flex; align-items: center;">
<span style="background: #4a90e2; color: white; border-radius: 50%; width: 30px; height: 30px; display: flex; align-items: center; justify-content: center; margin-right: 10px; font-size: 0.8em;">📚</span>
SC12B驱动库移植
</div>

基于 [liuquanli1970/SC12B](https://github.com/liuquanli1970/SC12B) 提供的库移植修改

<div style="border-top: 2px solid #4a90e2; margin: 16px 0; opacity: 0.3;"></div>

**SC12B.h** 修改说明

这里我们将 `writeRegister` 移动到 `public` 公开，方便外部调用灵敏度设置：

```cpp
public:
    bool writeRegister(uint8_t reg, uint8_t value);
```

**SC12B.cpp** 修改说明

这里我们将 `begin` 函数中内容修改成如下，使用默认地址和默认 I2C：

```cpp
void SC12B::begin() {
    Wire.begin();  // 使用默认I2C引脚 (SDA: GPIO4, SCL: GPIO5)
}
```

**移植优化要点:**

- 简化初始化流程，自动使用 NodeMCU 默认 I2C 引脚
- 公开寄存器写入接口，支持动态灵敏度调节
- 保持原库的核心功能，提升易用性
- 兼容 ESP8266 Arduino 框架的 Wire 库

</div>

### 7. config.h - 系统配置参数

**硬件配置:**

```cpp
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
#define TOUCH_INTERRUPT_PIN 14
#define BUZZER_PIN 12
```

**功能参数:**

```cpp
#define DEFAULT_NOTE_DURATION 500    // 默认音符时长
#define DEFAULT_OCTAVE_SHIFT 0       // 默认八度
#define DEFAULT_TOUCH_SENSITIVITY 0  // 默认触摸灵敏度
```

### 8. main.cpp - 主程序入口

**主要功能:**

- 系统初始化协调
- 主循环任务调度
- 多任务并发处理

**系统初始化流程:**

```cpp
void setup() {
  Serial.begin(115200);

  // 按顺序初始化各个模块
  initAudio();     // 音频系统初始化
  initTouch();     // 触摸检测初始化
  initDisplay();   // OLED显示初始化
  initNetwork();   // WiFi网络初始化

  // 显示启动信息
  showStartupScreen();
  showNetworkInfo();
  setupWebServer();

  delay(3000);
  displayMultipleKeys(0, 0);  // 显示初始界面
}
```

**主循环任务调度:**

```cpp
void loop() {
  /* ========== 混音播放状态维护 ========== */
  if (isMixPlaying) {
    unsigned long currentMicros = micros();
    if (currentMicros - lastMixUpdate >= MIX_UPDATE_INTERVAL) {
      updateMixedTone();
      lastMixUpdate = currentMicros;
    }
  }

  /* ========== 熄屏检测 ========== */
  checkScreenTimeout();

  /* ========== 触摸控制检测 ========== */
  unsigned long currentTime = millis();
  if (currentTime - lastSampleTime > SAMPLE_INTERVAL) {
    uint16_t keyValue = detectMultipleKeys();

    if (keyValue != previousKeys && currentTime - lastKeyTime > KEY_DEBOUNCE_TIME) {
      updateScreenActivity();  // 触摸时唤醒屏幕

      // 解析按键并处理
      int pressedKeys[12];
      int keyCount = 0;
      parseKeys(keyValue, pressedKeys, &keyCount);

      // 教学模式逻辑处理
      if (teachingMode && keyCount > 0) {
        handleTeachingMode(pressedKeys, keyCount);
      } else {
        displayMultipleKeys(pressedKeys, keyCount);
      }

      // 音频播放控制
      if (keyCount > 0) {
        playMultipleNotes(pressedKeys, keyCount);
      } else {
        stopAllAudio();
      }
    }
  }

  /* ========== 自动播放处理 ========== */
  if (autoPlayMode) {
    handleAutoPlay();
  }

  /* ========== Web命令处理 ========== */
  processWebCommands();
}
```

**任务调度特点:**

1. **混音播放维护**: 微秒级高频更新 (MIX_UPDATE_INTERVAL)
2. **触摸检测**: 中断+轮询双重机制，防抖处理
3. **显示更新**: 实时界面刷新，智能熄屏管理
4. **网络命令处理**: 异步 Web API 命令执行
5. **自动播放**: 定时音符播放，支持教学模式
6. **熄屏管理**: 多级超时检测和自动唤醒

## 技术亮点

### 1. 多点触摸算法

- 采用位运算快速解析多键状态
- 5 次采样合并提高检测精度
- 支持最多 12 键同时按下

### 2. 音频混音技术

- 实时频率平均算法
- PWM 波形生成
- 低延迟音频输出

### 3. Web 界面设计

- 响应式设计，支持移动端
- 实时参数同步
- 美观的渐变色彩方案

### 4. 教学系统

- 逐步引导学习
- 实时正确性反馈
- 可视化进度显示

## 项目架构

```
EDA-Piano 系统架构
├── 硬件层 (Hardware Layer)
│   ├── ESP8266 (NodeMCU v2) - 主控芯片
│   ├── SSD1306 OLED - 128x32显示屏
│   ├── SC12B - 12通道电容触摸芯片
│   └── Buzzer - PWM蜂鸣器 (GPIO12)
│
├── 驱动层 (Driver Layer)
│   ├── SC12B.cpp - 触摸芯片I2C驱动
│   ├── Adafruit_SSD1306 - OLED显示驱动
│   └── WiFi/AsyncWebServer - 网络通信驱动
│
├── 功能层 (Function Layer)
│   ├── audio.cpp - 音频播放和混音处理
│   ├── touch.cpp - 多点触摸检测和解析
│   ├── display.cpp - 界面绘制和熄屏管理
│   ├── network.cpp - Web服务器和API处理
│   └── music.cpp - 曲谱数据和播放控制
│
├── 应用层 (Application Layer)
│   ├── 触摸钢琴模式 - 物理按键演奏
│   ├── 网页钢琴模式 - 虚拟按键演奏
│   ├── 教学模式 - 引导式学习
│   └── 自动播放模式 - 歌曲欣赏
│
└── 用户接口 (User Interface)
    ├── OLED显示界面 - 本地可视化反馈
    └── Web界面 - 远程控制和参数调节
```

## 编译和部署

### 环境要求

- **开发环境**: PlatformIO IDE (推荐) 或 Arduino IDE
- **硬件平台**: ESP8266 Arduino Core v3.0+
- **编译器**: GCC for Xtensa
- **内存要求**: 至少 80KB RAM, 1MB Flash

### 项目配置文件 (platformio.ini)

```ini
[env:nodemcuv2]
platform = espressif8266
board = nodemcuv2
framework = arduino
monitor_speed = 115200

lib_deps =
  adafruit/Adafruit SSD1306 @ 2.5.15
  ottowinter/ESPAsyncWebServer-esphome @ ^3.3.0
  bblanchon/ArduinoJson @ ^7.2.0

build_flags =
  -DPIO_FRAMEWORK_ARDUINO_LWIP2_LOW_MEMORY
  -DVTABLES_IN_FLASH
  -fno-exceptions

upload_speed = 921600
```

### 编译步骤

```bash
# 1. 克隆项目
git clone <repository-url>
cd EDA-Piano

# 2. 安装PlatformIO (如果未安装)
pip install platformio

# 3. 编译项目
pio run

# 4. 上传到设备 (连接NodeMCU到USB)
pio run --target upload

# 5. 监控串口输出
pio device monitor
```

### 硬件连接图

```
NodeMCU v2 引脚连接:
├── I2C总线
│   ├── SDA (GPIO4/D2) → OLED SDA & SC12B SDA
│   └── SCL (GPIO5/D1) → OLED SCL & SC12B SCL
├── 音频输出
│   └── GPIO12 (D6) → 蜂鸣器正极
├── 触摸中断
│   └── GPIO14 (D5) → SC12B INT引脚
└── 电源
    ├── 3.3V → OLED VCC & SC12B VCC
    └── GND → 公共地线
```

### 首次部署检查清单

- [ ] 硬件连接正确，无短路
- [ ] USB 驱动已安装 (CP2102/CH340)
- [ ] 串口波特率设置为 115200
- [ ] WiFi 热点 "EDA-Piano" 可见
- [ ] 网页 192.168.4.1 可访问
- [ ] 触摸响应正常
- [ ] 音频输出正常
- [ ] OLED 显示正常

## 使用说明

### 1. 硬件连接

- OLED 显示屏连接到 I2C 接口
- SC12B 触摸芯片连接到 I2C 接口
- 蜂鸣器连接到 GPIO12
- 触摸中断连接到 GPIO14

### 2. 网络访问

1. 设备启动后会创建 WiFi 热点 "EDA-Piano"
2. 连接热点后访问 192.168.4.1
3. 通过 Web 界面控制钢琴功能

### 3. 操作模式详解

#### 🎹 触摸模式 (物理交互)

```cpp
// 触摸检测流程
void handleTouchMode() {
  uint16_t keyValue = detectMultipleKeys();  // 检测多键按下

  if (keyValue != 0) {
    int pressedKeys[12];
    int keyCount = 0;
    parseKeys(keyValue, pressedKeys, &keyCount);  // 解析按键

    displayMultipleKeys(pressedKeys, keyCount);   // OLED显示
    playMultipleNotes(pressedKeys, keyCount);     // 播放音符
  }
}
```

#### 🌐 网页模式 (远程控制)

- **虚拟键盘**: 响应式设计，支持手机/平板操作
- **实时同步**: 网页操作立即反映到硬件
- **参数调节**: 在线修改音符时长、八度、灵敏度

#### 📚 教学模式 (互动学习)

```cpp
// 教学模式核心逻辑
void handleTeachingMode(int* pressedKeys, int keyCount) {
  int* melody = getCurrentMelody();
  int expectedNote = melody[currentNoteIndex];

  if (keyCount == 1 && pressedKeys[0] == expectedNote) {
    // 按对了 - 显示成功提示
    currentNoteIndex++;
    showTeachingMode(getNextNote(), true, "Good!");

    if (currentNoteIndex >= getCurrentMelodyCount()) {
      showTeachingMode(0, true, "Complete!");
      teachingMode = false;  // 完成学习
    }
  } else {
    // 按错了 - 显示错误提示
    showTeachingMode(expectedNote, false, "Try Again!");
  }
}
```

#### 🎵 自动播放 (歌曲欣赏)

```cpp
// 自动播放定时器
void handleAutoPlay() {
  unsigned long currentTime = millis();

  if (currentTime - lastAutoPlayTime >= autoPlayInterval) {
    int* melody = getCurrentMelody();
    int note = melody[autoPlayIndex];

    if (note != 0) {  // 非休止符
      int keys[] = {note};
      playMultipleNotes(keys, 1);
      displayMultipleKeys(keys, 1);  // 同步显示
    }

    autoPlayIndex++;
    lastAutoPlayTime = currentTime;

    // 播放完成检查
    if (autoPlayIndex >= getCurrentMelodyCount()) {
      autoPlayMode = false;
      autoPlayIndex = 0;
    }
  }
}
```

### 4. Web 界面功能详解

#### 主界面布局

```html
<!-- 响应式钢琴键盘 -->
<div class="piano">
  <!-- 7个白键 -->
  <div class="white-key" onclick="playNote(1)">C</div>
  <div class="white-key" onclick="playNote(3)">D</div>
  <!-- ... -->

  <!-- 5个黑键 -->
  <div class="black-key" onclick="playNote(2)">C#</div>
  <div class="black-key" onclick="playNote(4)">D#</div>
  <!-- ... -->
</div>

<!-- 参数控制区域 -->
<div class="settings">
  <input
    type="range"
    id="duration"
    min="100"
    max="2000"
    oninput="updateDuration(this.value)"
  />
  <select id="octave" onchange="updateOctave(this.value)">
    <option value="-2">-2 (降低)</option>
    <option value="0" selected>0 (标准)</option>
    <option value="2">+2 (升高)</option>
  </select>
</div>
```

#### JavaScript 交互逻辑

```javascript
// 实时参数更新
function updateDuration(val) {
  fetch("/set/duration?value=" + val)
    .then((response) => response.text())
    .then((data) => {
      document.getElementById("durationValue").textContent = val + "ms";
    });
}

// 和弦播放
function playChord(keys) {
  fetch("/chord/" + keys.join(",")).then(() =>
    console.log("Chord played:", keys)
  );
}

// 状态监控
function checkStatus() {
  fetch("/status")
    .then((r) => r.json())
    .then((data) => {
      document.getElementById("status").textContent = "在线";
      updateUI(data); // 更新界面状态
    })
    .catch(() => {
      document.getElementById("status").textContent = "离线";
    });
}

setInterval(checkStatus, 5000); // 每5秒检查一次状态
```

## 扩展功能

### 可扩展方向

1. **更多歌曲**: 添加更多预置曲谱
2. **录音功能**: 记录和回放用户演奏
3. **蓝牙支持**: 无线 MIDI 输出
4. **音色扩展**: 支持多种乐器音色
5. **节拍器**: 添加节拍辅助功能

### 硬件升级

1. **更大显示屏**: 支持更丰富的界面
2. **立体声输出**: 双声道音频
3. **电池供电**: 便携式设计
4. **外壳设计**: 专业钢琴外观

## 性能优化

### 内存管理优化

```cpp
// 使用PROGMEM存储常量数据，节省RAM
const int PROGMEM baseFrequencies[] = {
  0, 262, 277, 294, 311, 330, 349,
  370, 392, 415, 440, 466, 494
};

// 使用volatile关键字优化中断变量
volatile bool isMixPlaying = false;
volatile int mixKeys[12];
volatile unsigned long lastMixUpdate = 0;
```

### 实时性能优化

```cpp
// 微秒级混音更新间隔
#define MIX_UPDATE_INTERVAL 50  // 50微秒

// 触摸采样间隔优化
#define SAMPLE_INTERVAL 20      // 20毫秒
#define KEY_DEBOUNCE_TIME 50    // 50毫秒防抖
```

### 网络性能优化

- 异步 Web 服务器，避免阻塞主循环
- 命令队列机制，分离网络处理和音频处理
- 响应式 Web 界面，支持移动端访问

## 故障排除

### 常见问题及解决方案

**1. 触摸不响应**

```cpp
// 检查I2C连接和中断配置
void debugTouch() {
  Serial.println("Touch Debug:");
  Serial.print("I2C Address: 0x");
  Serial.println(touchPannel.getAddress(), HEX);
  Serial.print("Interrupt Pin: ");
  Serial.println(digitalRead(TOUCH_INTERRUPT_PIN));
  Serial.print("Key Value: 0x");
  Serial.println(touchPannel.getKeyValue(), HEX);
}
```

**2. 音频输出异常**

```cpp
// 音频系统诊断
void debugAudio() {
  Serial.println("Audio Debug:");
  Serial.print("Buzzer Pin: ");
  Serial.println(BUZZER_PIN);
  Serial.print("Note Duration: ");
  Serial.println(noteDuration);
  Serial.print("Octave Shift: ");
  Serial.println(octaveShift);

  // 测试音频输出
  tone(BUZZER_PIN, 440, 1000);  // 播放A4音符1秒
}
```

**3. OLED 显示问题**

```cpp
// 显示系统检测
void debugDisplay() {
  if(!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println("OLED initialization failed!");
    Serial.println("Check I2C connections and address");
  } else {
    Serial.println("OLED initialized successfully");
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0,0);
    display.println("Display Test OK");
    display.display();
  }
}
```

**4. WiFi 连接问题**

- 检查热点名称和密码设置
- 确认 ESP8266 供电充足 (至少 500mA)
- 重启设备重新建立热点

**5. Web 界面无法访问**

- 确认已连接到 "EDA-Piano" 热点
- 浏览器访问 192.168.4.1
- 清除浏览器缓存重试

### 调试模式启用

```cpp
// 在config.h中添加调试开关
#define DEBUG_MODE 1

#if DEBUG_MODE
  #define DEBUG_PRINT(x) Serial.print(x)
  #define DEBUG_PRINTLN(x) Serial.println(x)
#else
  #define DEBUG_PRINT(x)
  #define DEBUG_PRINTLN(x)
#endif
```

## 项目特色

- **模块化设计**: 每个功能独立，便于维护和扩展
- **多点触控**: 支持最多 12 键同时按下，实现和弦演奏
- **网络控制**: 现代化响应式 Web 界面，支持移动端
- **教学功能**: 寓教于乐的逐步引导学习体验
- **实时性能**: 微秒级混音处理，毫秒级触摸响应
- **智能管理**: 自动熄屏、参数记忆、错误恢复
- **开源项目**: 完全开放源代码，MIT 许可证

## 技术创新点

1. **多点电容触摸算法**: 5 次采样合并 + 位运算解析
2. **实时音频混音**: 频率平均算法 + PWM 波形生成
3. **异步 Web 架构**: 命令队列 + 非阻塞处理
4. **智能界面管理**: 自适应显示 + 节能熄屏
5. **教学系统设计**: 实时反馈 + 进度跟踪

## 实际应用场景

### 🎓 教育领域

- **音乐启蒙**: 儿童音乐教育的互动工具
- **编程教学**: 嵌入式系统开发实践项目
- **STEM 教育**: 跨学科整合的典型案例

### 🏠 家庭娱乐

- **亲子互动**: 家长与孩子共同学习音乐
- **聚会娱乐**: 朋友聚会时的互动游戏
- **音乐练习**: 基础乐理和节拍训练

### 🔬 技术研究

- **IoT 原型**: 物联网设备开发参考
- **HCI 研究**: 人机交互界面设计
- **音频处理**: 实时音频算法验证

## 学习路径建议

### 🚀 初学者路径 (1-2 周)

```mermaid
graph LR
    A[硬件连接] --> B[基础编译]
    B --> C[触摸测试]
    C --> D[音频播放]
    D --> E[Web界面]
```

**第 1 周**: 硬件搭建和基础功能

- 学习 ESP8266 基础知识
- 完成硬件连接和测试
- 理解 I2C 通信原理
- 实现单音符播放

**第 2 周**: 软件功能和网络

- 掌握多点触摸算法
- 实现 Web 服务器
- 完成参数调节功能

### 🎯 进阶路径 (2-3 周)

```mermaid
graph LR
    A[音频混音] --> B[教学系统]
    B --> C[界面优化]
    C --> D[性能调优]
    D --> E[功能扩展]
```

**第 3 周**: 高级功能开发

- 深入理解混音算法
- 实现教学模式逻辑
- 优化显示界面效果

**第 4 周**: 系统优化和扩展

- 内存和性能优化
- 添加新歌曲和功能
- 错误处理和调试

### 🏆 专家路径 (持续改进)

- **硬件升级**: 更好的音频输出、更大显示屏
- **算法优化**: 更复杂的混音算法、音效处理
- **功能扩展**: MIDI 支持、录音回放、蓝牙连接
- **用户体验**: 更美观的界面、更智能的交互

## 代码贡献指南

### 📝 提交规范

```bash
# 功能添加
git commit -m "feat: 添加新的音效处理算法"

# 问题修复
git commit -m "fix: 修复触摸检测偶发失效问题"

# 文档更新
git commit -m "docs: 更新API接口说明"

# 性能优化
git commit -m "perf: 优化混音算法性能"
```

### 🔧 开发环境配置

```json
{
  "recommendations": [
    "platformio.platformio-ide",
    "ms-vscode.cpptools",
    "formulahendry.code-runner"
  ],
  "settings": {
    "C_Cpp.default.compilerPath": "~/.platformio/packages/toolchain-xtensa/bin/xtensa-lx106-elf-gcc",
    "C_Cpp.default.includePath": [
      "~/.platformio/packages/framework-arduinoespressif8266/cores/esp8266",
      "~/.platformio/packages/framework-arduinoespressif8266/libraries"
    ]
  }
}
```

### 🧪 测试用例示例

```cpp
// 音频系统单元测试
void testAudioSystem() {
  Serial.println("=== Audio System Test ===");

  // 测试频率计算
  assert(getNoteFrequency(1) == 262);  // C4
  assert(getNoteFrequency(10) == 440); // A4

  // 测试八度调节
  octaveShift = 1;
  assert(getNoteFrequency(1) == 524);  // C5

  // 测试混音功能
  int testKeys[] = {1, 5, 8};  // C大调和弦
  playMultipleNotes(testKeys, 3);
  delay(1000);

  Serial.println("Audio test passed!");
}

// 触摸系统测试
void testTouchSystem() {
  Serial.println("=== Touch System Test ===");

  // 测试I2C通信
  Wire.beginTransmission(0x40);
  int error = Wire.endTransmission();
  assert(error == 0);  // 通信正常

  // 测试按键解析
  uint16_t testValue = 0b0000000000010000;  // 模拟按键1
  int keys[12];
  int count = 0;
  parseKeys(testValue, keys, &count);
  assert(count == 1 && keys[0] == 1);

  Serial.println("Touch test passed!");
}
```

## 许可证和致谢

### 📄 开源许可

本项目采用 **MIT License**，允许自由使用、修改和分发。

### 🙏 特别致谢

- [liuquanli1970/SC12B](https://github.com/liuquanli1970/SC12B) - SC12B 驱动库
- [Adafruit SSD1306](https://github.com/adafruit/Adafruit_SSD1306) - OLED 显示驱动
- [ESPAsyncWebServer](https://github.com/me-no-dev/ESPAsyncWebServer) - 异步 Web 服务器
- ESP8266 Arduino 社区的所有贡献者

### 🌟 项目愿景

这个项目展示了嵌入式系统在音乐教育和娱乐领域的应用潜力，结合了硬件控制、软件算法和网络技术，是一个完整的物联网音乐设备解决方案。通过模块化设计和丰富的代码示例，为学习者提供了从硬件驱动到应用开发的完整技术栈参考。

我们希望这个项目能够：

- 🎵 **启发创造力**: 让更多人体验音乐与技术的结合
- 📚 **促进学习**: 为嵌入式开发学习者提供实践平台
- 🤝 **建立社区**: 聚集对音乐技术感兴趣的开发者
- 🚀 **推动创新**: 探索更多音乐设备的可能性
