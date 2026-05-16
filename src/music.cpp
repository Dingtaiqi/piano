#include "music.h"

// "一闪一闪亮晶晶"曲谱 (C大调) - 完整版
int twinkleMelody[] = {
  1, 1, 8, 8, 10, 10, 8,   // 一闪一闪亮晶晶 (C C G G A A G)
  6, 6, 5, 5, 3, 3, 1,     // 满天都是小星星 (F F E E D D C)
  8, 8, 6, 6, 5, 5, 3,     // 挂在天空放光明 (G G F F E E D)
  8, 8, 6, 6, 5, 5, 3,     // 好像许多小眼睛 (G G F F E E D)
  1, 1, 8, 8, 10, 10, 8,   // 一闪一闪亮晶晶 (C C G G A A G)
  6, 6, 5, 5, 3, 3, 1      // 满天都是小星星 (F F E E D D C)
};
int twinkleMelodyCount = 42;

// "两只老虎"曲谱 (C大调)
int tigerMelody[] = {
  1, 3, 5, 1,              // 两只老虎 (C D E C)
  1, 3, 5, 1,              // 两只老虎 (C D E C)
  5, 6, 8,               // 跑得快 (E F G -)
  5, 6, 8,               // 跑得快 (E F G -)
  8, 10, 8, 6, 5, 1,       // 一只没有眼睛 (G A G F E C)
  8, 10, 8, 6, 5, 1,       // 一只没有尾巴 (G A G F E C)
  3, 1, 1,              // 真奇怪 (C C C -)
  3, 1, 1,                // 真奇怪 (C C C -)
};
int tigerMelodyCount = 32;

// 当前教学曲目选择 (0=一闪一闪亮晶晶, 1=两只老虎)
int currentSong = 0;

// 获取当前教学曲谱
int* getCurrentMelody() {
  return currentSong == SONG_TWINKLE ? twinkleMelody : tigerMelody;
}

int getCurrentMelodyCount() {
  return currentSong == SONG_TWINKLE ? twinkleMelodyCount : tigerMelodyCount;
}

void setCurrentSong(int songId) {
  if (songId == SONG_TWINKLE || songId == SONG_TIGER) {
    currentSong = songId;
  }
}

String getCurrentSongName() {
  return currentSong == SONG_TWINKLE ? "一闪一闪亮晶晶" : "两只老虎";
}