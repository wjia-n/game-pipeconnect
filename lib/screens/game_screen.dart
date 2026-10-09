import 'dart:math';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/pipe_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/workshop.dart';
import '../theme/pipe_themes.dart';

/// What the player is playing.
enum GameMode { campaign, daily, seed }

class GameSetup {
  final GameMode mode;
  final PipeDifficulty difficulty;
  final int level; // campaign only, 0-based
  final int seed; // daily/seed
  final String label;
  const GameSetup({
    required this.mode,
    required this.difficulty,
    required this.level,
    required this.seed,
    required this.label,
  });
}

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.pipeconnect';

/// The puzzle board screen. The engine owns all state; this screen renders.
class GameScreen extends StatefulWidget {
  final GameSetup setup;
  final PipeAudio audio;
  final PipeSettings settings;
  final StoreService store;
  final VoidCallback? onNext; // campaign: advance a level

  const GameScreen({
    super.key,
    required this.setup,
    required this.audio,
    required this.settings,
    required this.store,
    this.onNext,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with WidgetsBindingObserver {
  late PipeEngine _engine;
  bool _pausedOverlay = false;
  bool _winHandled = false;

  PipeThemeDef get _t => PipeThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final s = widget.setup;
    final seed = s.mode == GameMode.campaign
        ? campaignSeed(s.difficulty, s.level)
        : s.seed;
    _engine = PipeEngine(
      puzzle: generatePuzzle(seed, s.difficulty),
      label: s.label,
      hintsUnlimited: widget.settings.isPro,
    );
    _engine.onEvent = _onEngineEvent;
    _engine.addListener(_onEngineChanged);
    widget.audio.startGameMusic();
  }

  void _onEngineEvent(PipeEvent e) {
    final a = widget.audio;
    switch (e) {
      case PipeEvent.twist:
        a.twist();
      case PipeEvent.flow:
        a.flow();
      case PipeEvent.connect:
        a.connect();
      case PipeEvent.hint:
        a.hint();
      case PipeEvent.hintDenied:
      case PipeEvent.invalid:
        a.invalid();
      case PipeEvent.levelStart:
        a.gameStart();
      case PipeEvent.win:
        a.win();
        _onWin();
    }
  }

  void _onEngineChanged() {
    if (!mounted) return;
    setState(() {});
    if (_engine.phase == Phase.over && !_winHandled) {
      _winHandled = true;
      _showWinSheet();
    }
  }

  Future<void> _onWin() async {
    final s = widget.setup;
    if (s.mode == GameMode.campaign) {
      await widget.settings.recordCampaignWin(
        s.difficulty,
        s.level,
        twists: _engine.moves,
      );
      // Review moment: every 3rd campaign win, graceful if not from Play.
      final done =
          widget.settings.campaignDone[s.difficulty.index] ?? 0;
      if (done > 0 && done % 3 == 0) _maybeReview();
    } else if (s.mode == GameMode.daily) {
      await widget.settings.recordDailyWin(DateTime.now());
      _maybeReview();
    } else {
      await widget.settings.recordBoardWin(twists: _engine.moves);
    }
  }

  Future<void> _maybeReview() async {
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    } catch (_) {
      // Not from Play / unavailable: stay silent.
    }
  }

  Future<void> _shareWin() async {
    widget.audio.click();
    await Share.share(
      'I solved ${_engine.label} in Pipe Connect with just ${_engine.moves} twists! Can you beat it? $_storeUrl',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Freeze the engine on interruption — watchdog resumes on return.
    if (state == AppLifecycleState.paused) {
      _engine.setPaused(true);
    } else if (state == AppLifecycleState.resumed) {
      if (!_pausedOverlay) _engine.setPaused(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _engine.dispose();
    super.dispose();
  }

  void _togglePause() {
    widget.audio.click();
    final toPause = !_pausedOverlay;
    setState(() => _pausedOverlay = toPause);
    _engine.setPaused(toPause);
  }

  void _exitToMenu() {
    widget.audio.click();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final e = _engine;
    return WorkshopBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    _HudRow(
                      theme: t,
                      engine: e,
                      label: e.label,
                      onPause: _togglePause,
                      onRestart: () {
                        widget.audio.click();
                        e.restart();
                      },
                      onExit: _exitToMenu,
                      onHint: () => e.hint(),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: _Board(
                            theme: t,
                            engine: e,
                            pipeStyle: widget.settings.pipeStyle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _StatusLine(theme: t, engine: e, settings: widget.settings),
                  ],
                ),
              ),
              if (_pausedOverlay) _PauseOverlay(theme: t, onResume: _togglePause, onExit: _exitToMenu),
              if (e.phase == Phase.celebrating)
                Center(child: _CelebrationBanner(theme: t)),
            ],
          ),
        ),
      ),
    );
  }

  void _showWinSheet() {
    final t = _t;
    final e = _engine;
    final s = widget.setup;
    final hasNext = s.mode == GameMode.campaign &&
        s.level + 1 < 60 &&
        widget.onNext != null;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 30),
        decoration: BoxDecoration(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(22)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.bgMid, t.tileEdge],
          ),
          border: Border.all(color: t.accent, width: 2.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pipeline flowing!', style: Workshop.display(28, theme: t)),
            const SizedBox(height: 8),
            Text(
              '${e.label} solved in ${e.moves} twists',
              style: Workshop.body(16, theme: t, color: t.muted),
              textAlign: TextAlign.center,
            ),
            if (s.mode == GameMode.daily) ...[
              const SizedBox(height: 4),
              Text(
                'Daily streak: ${widget.settings.dailyStreak} 🔥',
                style: Workshop.label(15, theme: t),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasNext)
                  WorkshopButton(
                    label: 'Next ▶',
                    width: 150,
                    fontSize: 17,
                    theme: t,
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).pop();
                      widget.onNext!();
                    },
                  ),
                if (hasNext) const SizedBox(width: 10),
                WorkshopButton(
                  label: hasNext ? 'Menu' : 'Play again',
                  width: 150,
                  fontSize: 17,
                  theme: t,
                  onTap: () {
                    widget.audio.click();
                    Navigator.of(context).pop();
                    if (!hasNext) {
                      // Seed/daily replay: fresh restart handled by caller.
                      _winHandled = false;
                      e.restart();
                    } else {
                      _exitToMenu();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                WorkshopIcon(
                    theme: t,
                    icon: Icons.share,
                    label: 'Share',
                    onTap: _shareWin),
                const SizedBox(width: 22),
                WorkshopIcon(
                    theme: t,
                    icon: Icons.refresh,
                    label: 'Replay',
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).pop();
                      _winHandled = false;
                      e.restart();
                    }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _HudRow extends StatelessWidget {
  final PipeThemeDef theme;
  final PipeEngine engine;
  final String label;
  final VoidCallback onPause;
  final VoidCallback onRestart;
  final VoidCallback onExit;
  final VoidCallback onHint;
  const _HudRow({
    required this.theme,
    required this.engine,
    required this.label,
    required this.onPause,
    required this.onRestart,
    required this.onExit,
    required this.onHint,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _smallBtn(theme, Icons.arrow_back, onExit),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: Workshop.display(19, theme: theme),
                  overflow: TextOverflow.ellipsis),
              Text('${engine.moves} twists',
                  style: Workshop.body(12, theme: theme, color: theme.muted)),
            ],
          ),
        ),
        _HintBtn(theme: theme, engine: engine, onHint: onHint),
        const SizedBox(width: 8),
        _smallBtn(theme, Icons.refresh, onRestart),
        const SizedBox(width: 8),
        _smallBtn(theme, Icons.pause, onPause),
      ],
    );
  }

  Widget _smallBtn(PipeThemeDef t, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.bgMid, t.tileEdge],
          ),
          border: Border.all(color: t.accent.withValues(alpha: 0.6), width: 2),
        ),
        child: Icon(icon, color: t.accentLight, size: 22),
      ),
    );
  }
}

class _HintBtn extends StatelessWidget {
  final PipeThemeDef theme;
  final PipeEngine engine;
  final VoidCallback onHint;
  const _HintBtn(
      {required this.theme, required this.engine, required this.onHint});

  @override
  Widget build(BuildContext context) {
    final left = engine.hintsLeft;
    final label = left > 90 ? '∞' : '$left';
    return GestureDetector(
      onTap: onHint,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.bgMid, theme.tileEdge],
          ),
          border:
              Border.all(color: theme.accent.withValues(alpha: 0.6), width: 2),
        ),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline,
                color: theme.accentLight, size: 20),
            const SizedBox(width: 4),
            Text(label, style: Workshop.label(15, theme: theme)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _Board extends StatelessWidget {
  final PipeThemeDef theme;
  final PipeEngine engine;
  final int pipeStyle;
  const _Board(
      {required this.theme, required this.engine, required this.pipeStyle});

  @override
  Widget build(BuildContext context) {
    final n = engine.n;
    return LayoutBuilder(builder: (_, constraints) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.tileEdge, theme.bgDeep],
          ),
          border: Border.all(color: theme.accent, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              offset: const Offset(0, 8),
              blurRadius: 16,
            ),
          ],
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: n,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: engine.tiles.length,
          itemBuilder: (_, i) => _Tile(
              theme: theme,
              engine: engine,
              index: i,
              pipeStyle: pipeStyle),
        ),
      );
    });
  }
}

class _Tile extends StatelessWidget {
  final PipeThemeDef theme;
  final PipeEngine engine;
  final int index;
  final int pipeStyle;
  const _Tile(
      {required this.theme,
      required this.engine,
      required this.index,
      required this.pipeStyle});

  @override
  Widget build(BuildContext context) {
    final ch = engine.tiles[index];
    final lit = engine.revealed.contains(index);
    final isPump = ch == 'P';
    final isEnd = _endpoint(ch);
    final isHint = engine.hintTile == index;
    return GestureDetector(
      onTap: () => engine.twist(index),
      child: AnimatedRotation(
        // Every twist visibly animates 90° — the weight of a wrench turn.
        turns: engine.twistCount[index] / 4,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.86, end: 1.0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          builder: (_, s, _) => Transform.scale(
            scale: s,
            child: Container(
              decoration: BoxDecoration(
                color: lit
                    ? theme.water.withValues(alpha: 0.16)
                    : theme.tile.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: isHint
                      ? theme.accentLight
                      : (lit
                          ? theme.water.withValues(alpha: 0.7)
                          : theme.tileEdge.withValues(alpha: 0.8)),
                  width: isHint ? 3 : 1.5,
                ),
                boxShadow: [
                  if (lit)
                    BoxShadow(
                      color: theme.waterHi,
                      blurRadius: 12,
                    ),
                  if (isHint)
                    BoxShadow(
                      color: theme.accentLight.withValues(alpha: 0.8),
                      blurRadius: 14,
                    ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    offset: const Offset(0, 3),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _PipePainter(
                  ch: ch,
                  lit: lit,
                  isPump: isPump,
                  isEnd: isEnd,
                  theme: theme,
                  style: pipeStyle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _endpoint(String ch) =>
      ch == 'a' || ch == 'b' || ch == 'c' || ch == 'd';
}

// ---------------------------------------------------------------------------
/// Pseudo-3D pipe painter with 8 physical rendering styles.
class _PipePainter extends CustomPainter {
  final String ch;
  final bool lit;
  final bool isPump;
  final bool isEnd;
  final PipeThemeDef theme;
  final int style;

  _PipePainter({
    required this.ch,
    required this.lit,
    required this.isPump,
    required this.isEnd,
    required this.theme,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final baseW = size.width * 0.24;
    final pipeColor = lit ? theme.water : theme.pipe;
    final w = baseW * _styleWidth(style);

    // Under-shadow for depth.
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    _drawPipes(canvas, c, size, shadowPaint, const Offset(1.5, 2.5));

    final body = Paint()
      ..color = pipeColor
      ..strokeWidth = w
      ..strokeCap = _capFor(style);
    _drawPipes(canvas, c, size, body, Offset.zero);

    // Highlight stripe for physicality.
    if (style != 4 || lit) {
      final hi = Paint()
        ..color = lit ? theme.waterHi : theme.pipeHi
        ..strokeWidth = w * 0.28
        ..strokeCap = StrokeCap.round;
      _drawPipes(canvas, c, size, hi, Offset(-w * 0.22, -w * 0.22));
    }

    // Style decorations.
    switch (style) {
      case 1: // Copper Coil: thread rings.
        _threadRings(canvas, c, size, w, pipeColor);
      case 2: // Industrial Ribbed: gap bands (drawn as dark bands).
        _ribBands(canvas, c, size, w);
      case 6: // Wood Inlay: dark wood casing behind the pipe.
        final casing = Paint()
          ..color = theme.tileEdge
          ..strokeWidth = w * 1.35
          ..strokeCap = StrokeCap.round;
        _drawPipes(canvas, c, size, casing, Offset.zero);
        _drawPipes(canvas, c, size, body, Offset.zero);
      case 7: // Brass Flanged: flange plates at openings.
        _flanges(canvas, c, size, w);
    }

    // Joint.
    if (style == 3) {
      _hexJoint(canvas, c, w, pipeColor);
    } else if (style == 7) {
      _flangeJoint(canvas, c, w, pipeColor);
    } else {
      // Coupling ring.
      canvas.drawCircle(
          c,
          w * 0.72,
          Paint()
            ..color = pipeColor
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          c,
          w * 0.72,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.14);
    }

    // Glass tube style: translucent casing.
    if (style == 4) {
      final casing = Paint()
        ..color = theme.text.withValues(alpha: 0.16)
        ..strokeWidth = w * 1.35
        ..strokeCap = StrokeCap.round;
      _drawPipes(canvas, c, size, casing, Offset.zero);
    }

    // Pump: brass flange with bolts + water drop.
    if (isPump) {
      final flange = Paint()
        ..color = theme.pump
        ..style = PaintingStyle.fill;
      canvas.drawCircle(c, w * 0.95, flange);
      canvas.drawCircle(
          c,
          w * 0.95,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      for (int k = 0; k < 4; k++) {
        final a = k * pi / 2 + pi / 4;
        canvas.drawCircle(
            c + Offset(cos(a), sin(a)) * w * 0.62,
            w * 0.12,
            Paint()..color = theme.tileEdge);
      }
      // Water core.
      canvas.drawCircle(
          c,
          w * 0.34,
          Paint()
            ..color = theme.water
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }

    // Endpoint: brass bulb ring at the opening mouth.
    if (isEnd) {
      final d = openingsOf(ch).single;
      final mouth = switch (d) {
        'N' => Offset(c.dx, size.height * 0.10),
        'S' => Offset(c.dx, size.height * 0.90),
        'E' => Offset(size.width * 0.90, c.dy),
        _ => Offset(size.width * 0.10, c.dy),
      };
      canvas.drawCircle(
          mouth,
          w * 0.52,
          Paint()
            ..color = lit ? theme.water : theme.endpoint
            ..maskFilter = lit
                ? const MaskFilter.blur(BlurStyle.normal, 3)
                : null);
      canvas.drawCircle(
          mouth,
          w * 0.52,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  double _styleWidth(int s) => switch (s) {
        2 => 0.9, // ribbed slimmer
        4 => 0.62, // glass inner tube
        _ => 1.0,
      };

  StrokeCap _capFor(int s) =>
      s == 3 || s == 7 ? StrokeCap.butt : StrokeCap.round;

  void _drawPipes(Canvas canvas, Offset c, Size size, Paint paint, Offset off) {
    for (final d in openingsOf(ch)) {
      final end = switch (d) {
        'N' => Offset(c.dx, 0),
        'S' => Offset(c.dx, size.height),
        'E' => Offset(size.width, c.dy),
        _ => Offset(0, c.dy),
      };
      canvas.drawLine(c + off, end + off, paint);
    }
  }

  void _threadRings(Canvas canvas, Offset c, Size size, double w, Color col) {
    final ring = Paint()
      ..color = col.withValues(alpha: 0.85)
      ..strokeWidth = 2.5;
    for (final d in openingsOf(ch)) {
      for (final f in [0.35, 0.55, 0.75]) {
        final p = switch (d) {
          'N' => Offset(c.dx, size.height * (0.5 - f * 0.5)),
          'S' => Offset(c.dx, size.height * (0.5 + f * 0.5)),
          'E' => Offset(size.width * (0.5 + f * 0.5), c.dy),
          _ => Offset(size.width * (0.5 - f * 0.5), c.dy),
        };
        final perp = (d == 'N' || d == 'S')
            ? Offset(w * 0.55, 0)
            : Offset(0, w * 0.55);
        canvas.drawLine(p - perp, p + perp, ring);
      }
    }
  }

  void _ribBands(Canvas canvas, Offset c, Size size, double w) {
    final band = Paint()..color = Colors.black.withValues(alpha: 0.4);
    for (final d in openingsOf(ch)) {
      for (final f in [0.3, 0.6]) {
        final p = switch (d) {
          'N' => Offset(c.dx, size.height * (0.5 - f * 0.5)),
          'S' => Offset(c.dx, size.height * (0.5 + f * 0.5)),
          'E' => Offset(size.width * (0.5 + f * 0.5), c.dy),
          _ => Offset(size.width * (0.5 - f * 0.5), c.dy),
        };
        final perp = (d == 'N' || d == 'S')
            ? Offset(w * 0.6, 0)
            : Offset(0, w * 0.6);
        canvas.drawLine(p - perp, p + perp,
            band..strokeWidth = size.width * 0.05);
      }
    }
  }

  void _flanges(Canvas canvas, Offset c, Size size, double w) {
    for (final d in openingsOf(ch)) {
      final p = switch (d) {
        'N' => Offset(c.dx, size.height * 0.06),
        'S' => Offset(c.dx, size.height * 0.94),
        'E' => Offset(size.width * 0.94, c.dy),
        _ => Offset(size.width * 0.06, c.dy),
      };
      canvas.drawCircle(p, w * 0.62,
          Paint()..color = lit ? theme.water : theme.accent);
      canvas.drawCircle(
          p,
          w * 0.62,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  void _hexJoint(Canvas canvas, Offset c, double w, Color col) {
    final path = Path();
    for (int k = 0; k < 6; k++) {
      final a = k * pi / 3;
      final p = c + Offset(cos(a), sin(a)) * w * 0.85;
      if (k == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = col);
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  void _flangeJoint(Canvas canvas, Offset c, double w, Color col) {
    canvas.drawCircle(c, w * 0.9, Paint()..color = col);
    for (int k = 0; k < 6; k++) {
      final a = k * pi / 3;
      canvas.drawCircle(c + Offset(cos(a), sin(a)) * w * 0.58, w * 0.1,
          Paint()..color = theme.tileEdge);
    }
  }

  @override
  bool shouldRepaint(covariant _PipePainter old) =>
      old.ch != ch ||
      old.lit != lit ||
      old.theme != theme ||
      old.style != style;
}

// ---------------------------------------------------------------------------
class _StatusLine extends StatelessWidget {
  final PipeThemeDef theme;
  final PipeEngine engine;
  final PipeSettings settings;
  const _StatusLine(
      {required this.theme, required this.engine, required this.settings});

  @override
  Widget build(BuildContext context) {
    final left = engine.puzzle.endpoints
        .where((e) => !engine.connected.contains(e))
        .length;
    final text = engine.phase == Phase.playing
        ? (left == 0
            ? 'All endpoints flowing!'
            : 'Feed every endpoint — $left to go')
        : 'Solved! 🎉';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.tileEdge.withValues(alpha: 0.7),
        border:
            Border.all(color: theme.accent.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Text(
        '${settings.playerNames.first}: $text',
        style: Workshop.body(13, theme: theme, color: theme.muted),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _CelebrationBanner extends StatelessWidget {
  final PipeThemeDef theme;
  const _CelebrationBanner({required this.theme});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (_, s, _) => Transform.scale(
        scale: s,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [theme.bgMid, theme.tileEdge],
            ),
            border: Border.all(color: theme.accentLight, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                offset: const Offset(0, 8),
                blurRadius: 18,
              ),
            ],
          ),
          child: Text('Solved! 🎉',
              style: Workshop.display(30, theme: theme)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _PauseOverlay extends StatelessWidget {
  final PipeThemeDef theme;
  final VoidCallback onResume;
  final VoidCallback onExit;
  const _PauseOverlay(
      {required this.theme, required this.onResume, required this.onExit});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [theme.bgMid, theme.tileEdge],
            ),
            border: Border.all(color: theme.accent, width: 2.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paused', style: Workshop.display(26, theme: theme)),
              const SizedBox(height: 18),
              WorkshopButton(
                  label: 'Resume',
                  width: 200,
                  fontSize: 17,
                  theme: theme,
                  onTap: onResume),
              const SizedBox(height: 10),
              WorkshopButton(
                  label: 'Quit to menu',
                  width: 200,
                  fontSize: 17,
                  theme: theme,
                  onTap: onExit),
            ],
          ),
        ),
      ),
    );
  }
}
