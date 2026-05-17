#include "music.h"

int twinkleMelody[] = {
  1, 1, 8, 8, 10, 10, 8,
  6, 6, 5, 5, 3, 3, 1,
  8, 8, 6, 6, 5, 5, 3,
  8, 8, 6, 6, 5, 5, 3,
  1, 1, 8, 8, 10, 10, 8,
  6, 6, 5, 5, 3, 3, 1
};
int twinkleMelodyCount = 42;

int tigerMelody[] = {
  1, 3, 5, 1,
  1, 3, 5, 1,
  5, 6, 8,
  5, 6, 8,
  8, 10, 8, 6, 5, 1,
  8, 10, 8, 6, 5, 1,
  3, 1, 1,
  3, 1, 1,
};
int tigerMelodyCount = 32;

int uploadedMelody[512] = {0};
int uploadedMelodyCount = 0;
char uploadedMelodyName[33] = "";
volatile bool uploadedPlayPending = false;

int currentSong = 0;

int* getCurrentMelody() {
  if (currentSong == SONG_UPLOADED) return uploadedMelody;
  return currentSong == SONG_TWINKLE ? twinkleMelody : tigerMelody;
}

int getCurrentMelodyCount() {
  if (currentSong == SONG_UPLOADED) return uploadedMelodyCount;
  return currentSong == SONG_TWINKLE ? twinkleMelodyCount : tigerMelodyCount;
}

void setCurrentSong(int songId) {
  if (songId >= SONG_TWINKLE && songId <= SONG_UPLOADED) {
    currentSong = songId;
  }
}

String getCurrentSongName() {
  if (currentSong == SONG_UPLOADED) return String(uploadedMelodyName);
  return currentSong == SONG_TWINKLE ? "一闪一闪亮晶晶" : "两只老虎";
}

void setUploadedMelody(const uint8_t* notes, int count, const char* name) {
  if (count > 512) count = 512;
  for (int i = 0; i < count; i++) {
    uploadedMelody[i] = notes[i];
  }
  uploadedMelodyCount = count;
  strncpy(uploadedMelodyName, name, 32);
  uploadedMelodyName[32] = '\0';
  setCurrentSong(SONG_UPLOADED);
}

void triggerUploadedPlayback() {
  uploadedPlayPending = true;
}
