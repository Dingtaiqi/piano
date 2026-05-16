#include "network.h"
#include "audio.h"
#include "touch.h"
#include "display.h"
#include "music.h"

// 网络相关变量
AsyncWebServer server(WEB_SERVER_PORT);
bool networkMode = false;
bool wifiConnected = false;

// Web命令队列
volatile int webCommand = 0;
volatile bool webCommandPending = false;

// 教学模式变量
bool teachingMode = false;
int currentNoteIndex = 0;
String teachingStatus = "";

// 自动播放变量
bool autoPlayMode = false;
int autoPlayIndex = 0;
unsigned long lastAutoPlayTime = 0;
int autoPlayInterval = 600; // 每个音符间隔600ms



void initNetwork() {
  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP(AP_SSID, AP_PASSWORD);
}

void connectToWiFi(const char* ssid, const char* password) {
  WiFi.begin(ssid, password);
  unsigned long startTime = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - startTime < 10000) {
    delay(500);
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    wifiConnected = true;
  }
}

String getAPIP() {
  return WiFi.softAPIP().toString();
}

// HTML页面生成函数
String generateMainPage() {
  String html = "<!DOCTYPE html><html><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>EDA-Piano</title>";
  html += "<style>body{font-family:Arial;margin:0;padding:10px;background:linear-gradient(135deg, #87CEEB, #4682B4);color:#003366;min-height:100vh}";
  html += ".container{max-width:100%;margin:0 auto;background:rgba(255,255,255,0.9);padding:15px;border-radius:15px;box-shadow:0 8px 16px rgba(0,51,102,0.2);backdrop-filter:blur(10px)}";
  html += "h1{text-align:center;margin-bottom:15px;font-size:1.8em;color:#1E90FF;text-shadow:2px 2px 4px rgba(0,0,0,0.1);font-weight:bold}";
  html += ".piano{position:relative;width:100%;max-width:350px;margin:15px auto;height:120px}";
  html += ".white-key{width:14.28%;height:120px;background:white;color:#333;border:1px solid #333;cursor:pointer;display:flex;align-items:end;justify-content:center;padding:3px;position:absolute;border-radius:0 0 5px 5px;font-size:12px}";
  html += ".black-key{width:8%;height:75px;background:#333;color:white;border:1px solid #000;cursor:pointer;display:flex;align-items:end;justify-content:center;padding:2px;position:absolute;z-index:2;border-radius:0 0 3px 3px;font-size:10px}";
  html += ".white-key:active,.black-key:active{transform:translateY(2px)}";
  html += ".settings{margin:15px 0}";
  html += ".setting-group{background:rgba(135,206,235,0.3);padding:12px;border-radius:10px;margin:10px 0;border:2px solid #87CEEB;box-shadow:0 2px 4px rgba(0,51,102,0.1)}";
  html += ".setting-group h3{margin:0 0 8px 0;font-size:14px;color:#1E90FF;font-weight:bold}";
  html += "input,select{width:100%;padding:8px;border:2px solid #87CEEB;border-radius:8px;background:rgba(255,255,255,0.8);color:#003366;box-sizing:border-box;transition:all 0.3s ease}";
  html += "input:focus,select:focus{border-color:#1E90FF;box-shadow:0 0 8px rgba(30,144,255,0.3);outline:none}";
  html += "button{width:100%;padding:12px;margin:5px 0;border:none;border-radius:8px;background:linear-gradient(45deg, #1E90FF, #00BFFF);color:white;cursor:pointer;font-weight:bold;transition:all 0.3s ease;box-shadow:0 4px 8px rgba(30,144,255,0.3)}";
  html += "button:hover{background:linear-gradient(45deg, #00BFFF, #87CEEB);transform:translateY(-2px);box-shadow:0 6px 12px rgba(30,144,255,0.4)}";
  html += ".status{text-align:center;margin:10px 0;padding:10px;background:rgba(135,206,235,0.2);border:2px solid #87CEEB;border-radius:8px;font-size:14px;color:#003366;font-weight:500}";
  html += "@media(max-width:480px){.container{padding:10px}.piano{height:100px}.white-key{height:100px}.black-key{height:65px}}";
  html += "</style></head><body>";
  html += "<div class='container'>";
  html += "<h1>🎹 EDA-Piano</h1>";
  html += "<div class='status'><p>状态: <span id='status'>-</span></p></div>";
  
  // 钢琴键盘
  html += "<div class='piano'>";
  // 白键
  html += "<div class='white-key' onclick='playNote(1)' style='left:0%'>C</div>";
  html += "<div class='white-key' onclick='playNote(3)' style='left:14.28%'>D</div>";
  html += "<div class='white-key' onclick='playNote(5)' style='left:28.56%'>E</div>";
  html += "<div class='white-key' onclick='playNote(6)' style='left:42.84%'>F</div>";
  html += "<div class='white-key' onclick='playNote(8)' style='left:57.12%'>G</div>";
  html += "<div class='white-key' onclick='playNote(10)' style='left:71.4%'>A</div>";
  html += "<div class='white-key' onclick='playNote(12)' style='left:85.68%'>B</div>";
  // 黑键
  html += "<div class='black-key' onclick='playNote(2)' style='left:10.2%'>C#</div>";
  html += "<div class='black-key' onclick='playNote(4)' style='left:24.48%'>D#</div>";
  html += "<div class='black-key' onclick='playNote(7)' style='left:52.98%'>F#</div>";
  html += "<div class='black-key' onclick='playNote(9)' style='left:67.26%'>G#</div>";
  html += "<div class='black-key' onclick='playNote(11)' style='left:81.54%'>A#</div>";
  html += "</div>";
  
 
  
  html += "<div class='setting-group'>";
  html += "<h3>预载歌曲</h3>";
  html += "<div style='display:flex;gap:10px;margin-bottom:10px;'>";
  html += "<button onclick='playSong(0)' style='flex:1;'>一闪一闪亮晶晶</button>";
  html += "<button onclick='startTeaching(0)' style='flex:1;'>开始学习</button>";
 
  html += "</div>";
  html += "<div style='display:flex;gap:10px;'>";
  html += "<button onclick='playSong(1)' style='flex:1;'>两只老虎</button>";
  html += "<button onclick='startTeaching(1)' style='flex:1;'>开始学习</button>";
  html += "</div>";
  html += "</div>";
   // 设置区域
  html += "<div class='settings'>";
  html += "<div class='setting-group'>";
  html += "<h3>音频设置</h3>";
  html += "<label>音符时长: <span id='durationValue'>" + String(noteDuration) + "ms</span></label>";
  html += "<input type='range' id='duration' min='100' max='2000' step='50' value='" + String(noteDuration) + "' oninput='updateDuration(this.value)'>";
  html += "</div>";
  html += "<div class='setting-group'>";
  html += "<h3>八度调节</h3>";
  html += "<select id='octave' onchange='updateOctave(this.value)'>";
  for(int i = -2; i <= 2; i++) {
    html += "<option value='" + String(i) + "'";
    if(i == octaveShift) html += " selected";
    html += ">" + String(i) + " (" + (i == 0 ? "标准" : (i > 0 ? "升高" : "降低")) + ")</option>";
  }
  html += "</select>";
  html += "</div>";
  html += "<div class='setting-group'>";
  html += "<h3>触摸灵敏度</h3>";
  html += "<label>灵敏度: <span id='sensitivityValue'>等级" + String(touchSensitivity) + "</span></label>";
  html += "<input type='range' id='sensitivity' min='0' max='15' step='1' value='" + String(touchSensitivity) + "' oninput='updateSensitivity(this.value)'>";
  html += "</div>";
  html += "<div class='setting-group'>";
  html += "<h3>熄屏设置</h3>";
  html += "<select id='screenOff' onchange='updateScreenOff(this.value)'>";
  html += "<option value='0'";
  if(screenOffMode == SCREEN_OFF_NONE) html += " selected";
  html += ">无</option>";
  html += "<option value='1'";
  if(screenOffMode == SCREEN_OFF_10SEC) html += " selected";
  html += ">10秒</option>";
  html += "<option value='2'";
  if(screenOffMode == SCREEN_OFF_1MIN) html += " selected";
  html += ">1分钟</option>";
  html += "<option value='3'";
  if(screenOffMode == SCREEN_OFF_5MIN) html += " selected";
  html += ">5分钟</option>";
  html += "<option value='4'";
  if(screenOffMode == SCREEN_OFF_15MIN) html += " selected";
  html += ">15分钟</option>";
  html += "<option value='5'";
  if(screenOffMode == SCREEN_OFF_30MIN) html += " selected";
  html += ">30分钟</option>";
  html += "</select>";
  html += "</div>";
  // 节拍器设置
  html += "<div class='setting-group'>";
  html += "<h3>节拍器</h3>";
  html += "<button id='metronomeToggle' onclick='toggleMetronome()'>" + String(metronomeEnabled ? "关闭" : "开启") + "节拍器</button>";
  html += "<label>BPM: <span id='bpmValue'>" + String(metronomeBPM) + "</span></label>";
  html += "<input type='range' id='bpm' min='40' max='240' step='1' value='" + String(metronomeBPM) + "' oninput='updateBPM(this.value)'>";
  html += "</div>";
  // 调音器设置（八度调节）
  html += "<div class='setting-group'>";
  html += "<h3>调音器 (八度)</h3>";
  html += "<div style='display: flex; gap: 10px; margin-bottom: 10px;'>";
  html += "<button onclick='tunerUp()'>升高八度</button>";
  html += "<button onclick='tunerDown()'>降低八度</button>";
  html += "</div>";
  html += "<div style='display: flex; gap: 10px;'>";
  html += "<button onclick='tunerReset()'>重置八度</button>";
  html += "<button onclick='tunerPlay()'>播放示例</button>";
  html += "</div>";
  html += "<label>当前八度偏移: <span id='octaveValue'>" + String(octaveShift) + "</span></label>";
  html += "</div>";
  html += "</div>";
  html += "<button onclick='playChord([1,5,8])'>C大调和弦</button>";
  html += "<button onclick='playChord([6,10,1])'>F大调和弦</button>";
  html += "<button onclick='playChord([8,12,3])'>G大调和弦</button>";
  html += "<button onclick='stopAll()'>停止播放</button>";
  html += "</div>";
  
  html += "<script>";
  html += "function playNote(k){fetch('/play/'+k);}";
  html += "function playChord(keys){fetch('/chord/'+keys.join(','));}";
  html += "function playSong(songId){fetch('/song/play?id='+songId);}";
  html += "function startTeaching(songId){fetch('/teaching/start?id='+songId);}";
  html += "function stopAll(){fetch('/stop');}";
  html += "function updateDuration(val){fetch('/set/duration?value='+val).then(r=>r.text()).then(d=>{document.getElementById('durationValue').textContent=val+'ms';});}";
  html += "function updateOctave(val){fetch('/set/octave?value='+val);}";
  html += "function updateSensitivity(val){fetch('/set/sensitivity?value='+val).then(r=>r.text()).then(d=>{document.getElementById('sensitivityValue').textContent='等级'+val;});}";
  html += "function updateScreenOff(val){fetch('/set/screenoff?value='+val);}";
  html += "function checkStatus(){fetch('/status').then(r=>r.json()).then(d=>{document.getElementById('status').textContent='在线';}).catch(()=>{document.getElementById('status').textContent='离线';});}";
  html += "setInterval(checkStatus,5000);checkStatus();";
  // 节拍器和调音器函数
  html += "function toggleMetronome(){fetch('/metronome/toggle').then(r=>r.text()).then(status=>{document.getElementById('metronomeToggle').textContent=(status=='ON'?'关闭':'开启')+'节拍器';});}";
  html += "function updateBPM(val){fetch('/metronome/set?bpm='+val).then(r=>r.text()).then(d=>{document.getElementById('bpmValue').textContent=val;});}";
  // 调音器八度调节函数
  html += "function tunerUp(){fetch('/tuner/up').then(r=>r.text()).then(octave=>{document.getElementById('octaveValue').textContent=octave;});}";
  html += "function tunerDown(){fetch('/tuner/down').then(r=>r.text()).then(octave=>{document.getElementById('octaveValue').textContent=octave;});}";
  html += "function tunerReset(){fetch('/tuner/reset').then(r=>r.text()).then(octave=>{document.getElementById('octaveValue').textContent=octave;});}";
  html += "function tunerPlay(){fetch('/tuner/play').then(r=>r.text());}";
  html += "</script></body></html>";
  return html;
}
void setupWebServer() {
  // 主页面
  server.on("/", HTTP_GET, [](AsyncWebServerRequest *request){
    request->send(200, "text/html", generateMainPage());
  });

  // 状态API
  server.on("/status", HTTP_GET, [](AsyncWebServerRequest *request){
    String json = "{\"duration\":" + String(noteDuration) + ",\"octave\":" + String(octaveShift) + ",\"sensitivity\":" + String(touchSensitivity) + ",\"screenOff\":" + String(screenOffMode) + ",\"wifi\":" + String(wifiConnected ? "true" : "false") + "}";
    request->send(200, "application/json", json);
  });

  // 播放音符API
  for(int i = 1; i <= 12; i++) {
    String path = "/play/" + String(i);
    server.on(path.c_str(), HTTP_GET, [i](AsyncWebServerRequest *request){ 
      webCommand = i; 
      webCommandPending = true; 
      request->send(200, "text/plain", "OK"); 
    });
  }

  // 和弦API
  server.on("/chord/1,5,8", HTTP_GET, [](AsyncWebServerRequest *request){ webCommand = 201; webCommandPending = true; request->send(200, "text/plain", "OK"); });
  server.on("/chord/6,10,1", HTTP_GET, [](AsyncWebServerRequest *request){ webCommand = 202; webCommandPending = true; request->send(200, "text/plain", "OK"); });
  server.on("/chord/8,12,3", HTTP_GET, [](AsyncWebServerRequest *request){ webCommand = 203; webCommandPending = true; request->send(200, "text/plain", "OK"); });

  // 歌曲播放API
  server.on("/song/play", HTTP_GET, [](AsyncWebServerRequest *request){
    if (request->hasParam("id")) {
      int songId = request->getParam("id")->value().toInt();
      setCurrentSong(songId);
      webCommand = 300; webCommandPending = true; 
      request->send(200, "text/plain", "OK");
    } else {
      request->send(400, "text/plain", "Missing song ID");
    }
  });

  // 教学模式API
  server.on("/teaching/start", HTTP_GET, [](AsyncWebServerRequest *request){
    if (request->hasParam("id")) {
      int songId = request->getParam("id")->value().toInt();
      setCurrentSong(songId);
      webCommand = 400; webCommandPending = true; 
      request->send(200, "text/plain", "OK");
    } else {
      request->send(400, "text/plain", "Missing song ID");
    }
  });

  // 控制命令
  server.on("/stop", HTTP_GET, [](AsyncWebServerRequest *request){
    webCommand = 100; webCommandPending = true; request->send(200, "text/plain", "OK");
  });

  // 设置API
  server.on("/set/duration", HTTP_GET, [](AsyncWebServerRequest *request){
    if (request->hasParam("value")) {
      int dur = request->getParam("value")->value().toInt();
      if (dur >= 100 && dur <= 2000) {
        noteDuration = dur;
        request->send(200, "text/plain", "OK");
      } else {
        request->send(400, "text/plain", "Invalid duration");
      }
    } else {
      request->send(400, "text/plain", "Missing value parameter");
    }
  });

  server.on("/set/octave", HTTP_GET, [](AsyncWebServerRequest *request){
    if (request->hasParam("value")) {
      int oct = request->getParam("value")->value().toInt();
      if (oct >= -2 && oct <= 2) {
        octaveShift = oct;
        request->send(200, "text/plain", "OK");
      } else {
        request->send(400, "text/plain", "Invalid octave");
      }
    } else {
      request->send(400, "text/plain", "Missing value parameter");
    }
  });

  server.on("/set/sensitivity", HTTP_GET, [](AsyncWebServerRequest *request){
    if (request->hasParam("value")) {
      int sens = request->getParam("value")->value().toInt();
      if (sens >= 0 && sens <= 15) {
        touchSensitivity = sens;
        applyTouchSensitivity();
        request->send(200, "text/plain", "OK");
      } else {
        request->send(400, "text/plain", "Invalid sensitivity");
      }
    } else {
      request->send(400, "text/plain", "Missing value parameter");
    }
  });

  server.on("/set/screenoff", HTTP_GET, [](AsyncWebServerRequest *request){
    if (request->hasParam("value")) {
      int mode = request->getParam("value")->value().toInt();
      if (mode >= 0 && mode <= 5) {
        screenOffMode = mode;
        lastActivityTime = millis(); // 重置活动时间
        if (!screenOn) {
          turnOnScreen(); // 如果当前熄屏，立即亮屏
        }
        request->send(200, "text/plain", "OK");
      } else {
        request->send(400, "text/plain", "Invalid screen off mode");
      }
    } else {
      request->send(400, "text/plain", "Missing value parameter");
    }
  });

  // 节拍器控制
  server.on("/metronome/toggle", HTTP_GET, [](AsyncWebServerRequest *request){
    metronomeEnabled = !metronomeEnabled;
    if (metronomeEnabled) {
      lastMetronomeTick = millis();
    }
    request->send(200, "text/plain", metronomeEnabled ? "ON" : "OFF");
  });

  server.on("/metronome/set", HTTP_GET, [](AsyncWebServerRequest *request){
    if (request->hasParam("bpm")) {
      int bpm = request->getParam("bpm")->value().toInt();
      if (bpm >= 40 && bpm <= 240) {
        metronomeBPM = bpm;
        request->send(200, "text/plain", "OK");
      } else {
        request->send(400, "text/plain", "BPM out of range (40-240)");
      }
    } else {
      request->send(400, "text/plain", "Missing bpm parameter");
    }
  });

  // 调音器控制（八度调节）
  server.on("/tuner/up", HTTP_GET, [](AsyncWebServerRequest *request){
    if (octaveShift < 2) {
      octaveShift++;
      // 播放示例音调
      tone(BUZZER_PIN, getNoteFrequency(1), 500); // 播放C4（根据八度偏移调整）
    }
    request->send(200, "text/plain", String(octaveShift));
  });

  server.on("/tuner/down", HTTP_GET, [](AsyncWebServerRequest *request){
    if (octaveShift > -2) {
      octaveShift--;
      tone(BUZZER_PIN, getNoteFrequency(1), 500);
    }
    request->send(200, "text/plain", String(octaveShift));
  });

  server.on("/tuner/reset", HTTP_GET, [](AsyncWebServerRequest *request){
    octaveShift = 0;
    tone(BUZZER_PIN, getNoteFrequency(1), 500);
    request->send(200, "text/plain", "0");
  });

  server.on("/tuner/play", HTTP_GET, [](AsyncWebServerRequest *request){
    tone(BUZZER_PIN, getNoteFrequency(1), 500);
    request->send(200, "text/plain", "OK");
  });

  server.begin();
}

void processWebCommands() {
  if (!webCommandPending) return;
  
  webCommandPending = false;
  
  if (webCommand >= 1 && webCommand <= 12) {
    // 播放单个音符
    int keys[] = {webCommand};
    playMultipleNotes(keys, 1);
  }
  else if (webCommand == 100) {
    // 停止播放
    stopAllAudio();
    autoPlayMode = false;
    autoPlayIndex = 0;
  }
  else if (webCommand == 201) {
    // C大调和弦
    int keys[] = {1, 5, 8};
    playMultipleNotes(keys, 3);
  }
  else if (webCommand == 202) {
    // F大调和弦
    int keys[] = {6, 10, 1};
    playMultipleNotes(keys, 3);
  }
  else if (webCommand == 203) {
    // G大调和弦
    int keys[] = {8, 12, 3};
    playMultipleNotes(keys, 3);
  }
  else if (webCommand == 300) {
    // 播放选定的歌曲
    autoPlayMode = true;
    autoPlayIndex = -1;  // 设置为-1，这样main.cpp中递增后就是0
    lastAutoPlayTime = millis() - autoPlayInterval;  // 立即触发第一个音符播放
  }
  else if (webCommand == 400) {
    // 启动教学模式
    teachingMode = true;
    currentNoteIndex = 0;
    teachingStatus = "Teaching Started";
    
    // 立即显示教学界面
    int* melody = getCurrentMelody();
    int melodyCount = getCurrentMelodyCount();
    int nextNote = melody[currentNoteIndex];
    if (nextNote == 0 && currentNoteIndex + 1 < melodyCount) {
      currentNoteIndex++;
      nextNote = melody[currentNoteIndex];
    }
    showTeachingMode(nextNote, false, "");
  }
  
  webCommand = 0;
}