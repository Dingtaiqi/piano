#include <Arduino.h>
#include "config.h"
#include "audio.h"
#include "touch.h"
#include "display.h"
#include "network.h"
#include "music.h"
#include "pcm_audio.h"
#include "pic.cpp"

void setup() {
  Serial.begin(115200);

  // 初始化各个模块
  initAudio();
  pcmInit();
  initTouch();
  initDisplay();
  initNetwork();
  
  // 显示启动画面
  showStartupScreen();
  
  // 显示网络信息
  showNetworkInfo();
  
  // 启动Web服务器
  setupWebServer();
  
  delay(3000);
  
  // 显示初始钢琴界面
  displayMultipleKeys(0, 0);
}

void loop() {
  /* ========== 上位机通信 ========== */
  pcmProcessSerial();

  /* ========== 上位机旋律播放触发 ========== */
  if (uploadedPlayPending) {
    uploadedPlayPending = false;
    setCurrentSong(SONG_UPLOADED);
    autoPlayMode = true;
    autoPlayIndex = -1;
    currentNoteIndex = 0;
    teachingMode = false;
    autoPlayInterval = 500;
    lastAutoPlayTime = millis();
  }

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
  {
    unsigned long currentTime = millis();
    
    if (currentTime - lastSampleTime > SAMPLE_INTERVAL) {
      
      uint16_t keyValue = detectMultipleKeys();
      
      if (keyValue != previousKeys && currentTime - lastKeyTime > KEY_DEBOUNCE_TIME) {
        
        // 触摸时更新屏幕活动时间（包括亮屏）
        updateScreenActivity();
        
        currentKeys = keyValue;
        previousKeys = keyValue;
        lastKeyTime = currentTime;
        
        int pressedKeys[12];
        int keyCount = 0;
        
        parseKeys(keyValue, pressedKeys, &keyCount);
        
        // 教学模式处理
        if (teachingMode && keyCount > 0) {
          int* melody = getCurrentMelody();
          int melodyCount = getCurrentMelodyCount();
          int expectedNote = melody[currentNoteIndex];
          if (expectedNote == 0) {
            // 跳过休止符
            currentNoteIndex++;
            if (currentNoteIndex < melodyCount) {
              expectedNote = melody[currentNoteIndex];
            }
          }
          
          if (keyCount == 1 && pressedKeys[0] == expectedNote) {
            // 按对了
            currentNoteIndex++;
            if (currentNoteIndex >= melodyCount) {
              showTeachingMode(0, true, "Complete!");
              teachingMode = false;
            } else {
              int nextNote = melody[currentNoteIndex];
              if (nextNote == 0 && currentNoteIndex + 1 < melodyCount) {
                currentNoteIndex++;
                nextNote = melody[currentNoteIndex];
              }
              showTeachingMode(nextNote, true, "Good!");
            }
          } else {
            // 按错了
            showTeachingMode(expectedNote, false, "Error!");
          }
        } else if (teachingMode) {
          // 教学模式但没有按键，显示下一个要按的键
          int* melody = getCurrentMelody();
          int melodyCount = getCurrentMelodyCount();
          int nextNote = melody[currentNoteIndex];
          if (nextNote == 0 && currentNoteIndex + 1 < melodyCount) {
            currentNoteIndex++;
            nextNote = melody[currentNoteIndex];
          }
          showTeachingMode(nextNote, false, "");
        } else {
          // 正常模式
          displayMultipleKeys(pressedKeys, keyCount);
        }
        
        {
          if (keyCount > 0) {
            playMultipleNotes(pressedKeys, keyCount);
          } else {
            stopAllAudio();
          }
        }
      }

      lastSampleTime = currentTime;
    }
  }

  /* ========== 中断驱动的触摸检测 ========== */
  if (iftouch) {
    iftouch = false;
    
    unsigned long currentTime = millis();
    
    if (currentTime - lastSampleTime > SAMPLE_INTERVAL) {
      uint16_t keyValue = detectMultipleKeys();
      
      if (keyValue != previousKeys) {
        
        // 触摸时更新屏幕活动时间（包括亮屏）
        updateScreenActivity();
        
        currentKeys = keyValue;
        previousKeys = keyValue;
        lastKeyTime = currentTime;
        
        int pressedKeys[12];
        int keyCount = 0;
        
        parseKeys(keyValue, pressedKeys, &keyCount);
        
        // 教学模式处理
        if (teachingMode && keyCount > 0) {
          int* melody = getCurrentMelody();
          int melodyCount = getCurrentMelodyCount();
          int expectedNote = melody[currentNoteIndex];
          if (expectedNote == 0) {
            // 跳过休止符
            currentNoteIndex++;
            if (currentNoteIndex < melodyCount) {
              expectedNote = melody[currentNoteIndex];
            }
          }
          
          if (keyCount == 1 && pressedKeys[0] == expectedNote) {
            // 按对了
            currentNoteIndex++;
            if (currentNoteIndex >= melodyCount) {
              showTeachingMode(0, true, "Complete!");
              teachingMode = false;
            } else {
              int nextNote = melody[currentNoteIndex];
              if (nextNote == 0 && currentNoteIndex + 1 < melodyCount) {
                currentNoteIndex++;
                nextNote = melody[currentNoteIndex];
              }
              showTeachingMode(nextNote, true, "Good!");
            }
          } else {
            // 按错了
            showTeachingMode(expectedNote, false, "Error!");
          }
        } else if (teachingMode) {
          // 教学模式但没有按键，显示下一个要按的键
          int* melody = getCurrentMelody();
          int melodyCount = getCurrentMelodyCount();
          int nextNote = melody[currentNoteIndex];
          if (nextNote == 0 && currentNoteIndex + 1 < melodyCount) {
            currentNoteIndex++;
            nextNote = melody[currentNoteIndex];
          }
          showTeachingMode(nextNote, false, "");
        } else {
          // 正常模式
          displayMultipleKeys(pressedKeys, keyCount);
        }
        
        {
          if (keyCount > 0) {
            playMultipleNotes(pressedKeys, keyCount);
          } else {
            stopAllAudio();
          }
        }
      }

      lastSampleTime = currentTime;
    }
  }

  /* ========== 自动播放处理 ========== */
  if (autoPlayMode) {
    unsigned long currentTime = millis();
    if (currentTime - lastAutoPlayTime >= (unsigned long)autoPlayInterval) {
      autoPlayIndex++;
      int melodyCount = getCurrentMelodyCount();
      if (autoPlayIndex >= melodyCount) {
        // 播放完成
        autoPlayMode = false;
        autoPlayIndex = 0;
        stopAllAudio();
      } else {
        // 播放下一个音符
        int* melody = getCurrentMelody();
        int keys[] = {melody[autoPlayIndex]};
        playMultipleNotes(keys, 1);
        lastAutoPlayTime = currentTime;
      }
    }
  }

  /* ========== Web命令处理 ========== */
  processWebCommands();

  /* ========== 节拍器处理 ========== */
  if (metronomeEnabled && !tunerEnabled) {
    unsigned long currentTime = millis();
    unsigned long interval = 60000 / metronomeBPM; // 计算节拍间隔(ms)
    if (currentTime - lastMetronomeTick >= interval) {
      // 播放节拍音 (短促的咔嗒声, PCM 播放时跳过)
      tone(BUZZER_PIN, 1000, 50); // 1kHz, 50ms
      lastMetronomeTick = currentTime;
    }
  }
}