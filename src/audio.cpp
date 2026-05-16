#include "audio.h"

// 音频设置变量
int noteDuration = DEFAULT_NOTE_DURATION;
int octaveShift = DEFAULT_OCTAVE_SHIFT;

// 混音播放相关变量
volatile bool isMixPlaying = false;
volatile int mixKeys[12];
volatile int mixKeyCount = 0;
volatile unsigned long mixStartTime = 0;
volatile unsigned long lastMixUpdate = 0;

// 节拍器变量
bool metronomeEnabled = false;
int metronomeBPM = 120;
unsigned long lastMetronomeTick = 0;

// 调音器变量
bool tunerEnabled = false;

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

String keyString[] = {
  "",   // 占位，索引从1开始
  "C", "C#", "D", "D#", "E", "F", 
  "F#", "G", "G#", "A", "A#", "B"
};

void initAudio() {
  pinMode(BUZZER_PIN, OUTPUT);
}

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

// 简化的混音播放 - 使用PWM方式
void updateMixedTone() {
  if (!isMixPlaying || mixKeyCount == 0) return;
  
  unsigned long currentTime = millis();
  
  // 检查播放时长，使用统一的音长设置
  if (currentTime - mixStartTime > noteDuration) {
    isMixPlaying = false;
    digitalWrite(BUZZER_PIN, LOW);
    return;
  }
  
  // 计算混合频率（简单平均）
  float avgFrequency = 0;
  for (int i = 0; i < mixKeyCount; i++) {
    avgFrequency += getNoteFrequency(mixKeys[i]);
  }
  avgFrequency /= mixKeyCount;
  
  // 使用tone函数播放平均频率
  tone(BUZZER_PIN, (int)avgFrequency, 100);
}

// 开始播放混音
void playMultipleNotes(int* keys, int keyCount) {
  // 停止之前的播放
  isMixPlaying = false;
  noTone(BUZZER_PIN);
  
  if (keyCount == 0) {
    return;
  }
  
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
    
    // 立即开始播放
    updateMixedTone();
  }
}

void stopAllAudio() {
  isMixPlaying = false;
  noTone(BUZZER_PIN);
  digitalWrite(BUZZER_PIN, LOW);
}