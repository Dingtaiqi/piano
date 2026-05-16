#ifndef MUSIC_H
#define MUSIC_H

#include <Arduino.h>

// 歌曲ID定义
#define SONG_TWINKLE 0
#define SONG_TIGER 1

// 曲谱数据
extern int twinkleMelody[];
extern int twinkleMelodyCount;
extern int tigerMelody[];
extern int tigerMelodyCount;

// 当前选择的歌曲
extern int currentSong;

// 函数声明
int* getCurrentMelody();
int getCurrentMelodyCount();
void setCurrentSong(int songId);
String getCurrentSongName();

#endif