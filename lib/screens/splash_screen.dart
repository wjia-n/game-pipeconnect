import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/workshop.dart';
import '../theme/pipe_themes.dart';
import 'menu_screen.dart';

/// Launch splash: WAJIHA company moment, then the game splash —
/// logo + name + animated loading line + "Credits: WAJIHA".
class SplashScreen extends StatefulWidget {
  final PipeAudio audio;
  final PipeSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;
  bool _companyDone = false;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the company logo shows, then start menu music.
    widget.audio.prewarm();
    widget.audio.startMenuMusic();
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() => _companyDone = true);
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = PipeThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    return Scaffold(
      backgroundColor: const Color(0xFF17100A),
      body: _companyDone
          ? _GameSplash(theme: theme, loader: _loader)
          : _CompanySplash(theme: theme),
    );
  }
}

/// Company moment: the official WAJIHA logo, untouched.
class _CompanySplash extends StatelessWidget {
  final PipeThemeDef theme;
  const _CompanySplash({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 700),
        builder: (_, v, _) => Opacity(
          opacity: v,
          child: Image.asset('assets/wajiha_logo.png',
              width: 170, height: 170, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// Game splash: logo + name + animated loading line + credits.
class _GameSplash extends StatelessWidget {
  final PipeThemeDef theme;
  final AnimationController loader;
  const _GameSplash({required this.theme, required this.loader});

  @override
  Widget build(BuildContext context) {
    return WorkshopBackdrop(
      theme: theme,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: theme.accent, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    offset: const Offset(0, 10),
                    blurRadius: 24,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/pipeconnect_logo.png',
                  fit: BoxFit.cover),
            ),
            const SizedBox(height: 22),
            Text('Pipe Connect', style: Workshop.display(48, theme: theme)),
            const SizedBox(height: 6),
            Text(
              'TWIST · FLOW · WIN',
              style: Workshop.label(13, theme: theme),
            ),
            const SizedBox(height: 30),
            // Animated loading line.
            SizedBox(
              width: 220,
              child: AnimatedBuilder(
                animation: loader,
                builder: (_, _) => Column(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.black.withValues(alpha: 0.45),
                        border: Border.all(
                            color: theme.accent.withValues(alpha: 0.5)),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: loader.value.clamp(0.02, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: LinearGradient(
                              colors: [
                                theme.accentLight,
                                theme.accent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      loader.value < 1
                          ? 'Pressurizing the pipes…'
                          : 'Ready!',
                      style: Workshop.body(13,
                          theme: theme,
                          color: theme.muted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 44),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/wajiha_logo.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Text(
                  'Credits: WAJIHA',
                  style: Workshop.label(14, theme: theme),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
