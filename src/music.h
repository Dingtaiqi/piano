#ifndef MUSIC_H
#define MUSIC_H

#include <Arduino.h>

#define SONG_TWINKLE 0
#define SONG_TIGER 1
#define SONG_UPLOADED 2

extern int twinkleMelody[];
extern int twinkleMelodyCount;
extern int tigerMelody[];
extern int tigerMelodyCount;

// 上位机传入的旋律
extern int8_t uploadedMelody[];
extern int uploadedMelodyCount;
extern char uploadedMelodyName[];
extern volatile bool uploadedPlayPending;

extern int currentSong;

int* getCurrentMelody();
int getCurrentMelodyCount();
void setCurrentSong(int songId);
String getCurrentSongName();

void setUploadedMelody(const int8_t* notes, int count, const char* name);
void triggerUploadedPlayback();

#endif
