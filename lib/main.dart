import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/settings_service.dart';
import 'theme/workshop.dart';
import 'theme/pipe_themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final settings = PipeSettings();
  await settings.load();
  final audio = PipeAudio();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.volume,
  );
  runApp(PipeConnectApp(settings: settings, audio: audio));
}

class PipeConnectApp extends StatefulWidget {
  final PipeSettings settings;
  final PipeAudio audio;
  const PipeConnectApp({super.key, required this.settings, required this.audio});

  @override
  State<PipeConnectApp> createState() => _PipeConnectAppState();
}

class _PipeConnectAppState extends State<PipeConnectApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause (not stop) on interruption so music resumes exactly where it
    // left off; game screens additionally freeze their engines.
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) => MaterialApp(
        title: 'Pipe Connect',
        debugShowCheckedModeBanner: false,
        theme: Workshop.theme(PipeThemes.byId(widget.settings.themeId,
            custom: widget.settings.customTheme)),
        home: SplashScreen(audio: widget.audio, settings: widget.settings),
      ),
    );
  }
}
