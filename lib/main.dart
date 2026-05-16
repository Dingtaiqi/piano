import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'pages/home_page.dart';
import 'services/audio_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 FFmpeg 目录: 依次查找 exe同目录, ffmpeg子目录, 当前目录
  final ffmpegName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  for (final dir in [exeDir, '$exeDir/ffmpeg', 'ffmpeg']) {
    if (File('$dir/$ffmpegName').existsSync()) {
      AudioService.init(dir);
      break;
    }
  }

  runApp(
    const ProviderScope(
      child: PianoApp(),
    ),
  );
}

class PianoApp extends StatelessWidget {
  const PianoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP8266 电子琴',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}
