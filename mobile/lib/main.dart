import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'constants/colors.dart';
import 'services/api_service.dart';
import 'services/audio_player_handler.dart';
import 'screens/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay (transparent status bar for edge-to-edge Spotify experience)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: SpotifyColors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialize API service
  await apiService.init();

  // Initialize Background Audio Service for iOS Lock Screen & Control Center
  audioHandler = await AudioService.init(
    builder: () => SpotigramAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.spotigram.music.channel.audio',
      androidNotificationChannelName: 'Spotigram Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: true,
    ),
  );

  runApp(const SpotigramApp());
}

class SpotigramApp extends StatelessWidget {
  const SpotigramApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spotigram',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: SpotifyColors.black,
        primaryColor: SpotifyColors.green,
        colorScheme: const ColorScheme.dark(
          primary: SpotifyColors.green,
          secondary: SpotifyColors.greenLight,
          surface: SpotifyColors.darkGrey,
          background: SpotifyColors.black,
        ),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        fontFamily: 'Roboto',
      ),
      home: const MainShell(),
    );
  }
}
