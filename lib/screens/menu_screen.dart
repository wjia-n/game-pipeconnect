import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/pipe_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/workshop.dart';
import '../theme/pipe_themes.dart';
import 'custom_theme_screen.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.pipeconnect';

/// Main menu — Pipe Workshop edition.
/// Logo, mode selection (Campaign / Daily / Seed), difficulty, theme + pipe
/// style pickers, player rename, tip jar, settings.
class MenuScreen extends StatefulWidget {
  final PipeAudio audio;
  final PipeSettings settings;

  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final StoreService _store = StoreService();

  PipeSettings get _s => widget.settings;
  PipeThemeDef get _t => PipeThemes.byId(_s.themeId, custom: _s.customTheme);

  @override
  void initState() {
    super.initState();
    widget.audio.startMenuMusic();
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
    _store.lastThanks.addListener(_onThanks);
    _store.proPurchased.addListener(_onPro);
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Workshop.body(15, theme: _t)),
        backgroundColor: _t.tileEdge,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _store.lastThanks.value = null;
  }

  void _onPro() {
    if (_store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      _store.proPurchased.value = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.proPurchased.removeListener(_onPro);
    _store.dispose();
    super.dispose();
  }

  /// Real in-app review flow: the Play in-app review sheet when available,
  /// otherwise fall back to opening the store listing. No fake dialogs.
  Future<void> _requestReview() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing(appStoreId: null);
      }
    } catch (_) {
      // Review UI unavailable on this device/build: stay silent, no fake UI.
    }
  }

  void _playCampaign() {
    final d = PipeDifficulty.values[_s.difficulty];
    final level = (_s.campaignDone[d.index] ?? 0).clamp(0, 59);
    _openCampaignLevel(d, level);
  }

  /// Guard so advancing to the next board doesn't restart menu music.
  bool _advancing = false;

  void _openCampaignLevel(PipeDifficulty d, int level) {
    widget.audio.gameStart();
    _openGame(
      GameSetup(
        mode: GameMode.campaign,
        difficulty: d,
        level: level,
        seed: campaignSeed(d, level),
        label:
            'Board ${level + 1} · ${difficultySpecs[d]!.label} (${difficultySpecs[d]!.size}×${difficultySpecs[d]!.size})',
      ),
      onNext: level + 1 < 60
          ? () {
              _advancing = true;
              Navigator.of(context).pop(); // pop the finished game screen
              _openCampaignLevel(d, level + 1);
            }
          : null,
    );
  }

  void _playDaily() {
    widget.audio.gameStart();
    final now = DateTime.now();
    _openGame(GameSetup(
      mode: GameMode.daily,
      difficulty: PipeDifficulty.medium,
      level: 0,
      seed: dailySeed(now),
      label: 'Daily ${PipeSettings.dateKey(now)}',
    ));
  }

  void _playSeed() {
    widget.audio.click();
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
                colors: [_t.bgMid, _t.tileEdge],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            border: Border.all(color: _t.accent, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Seed Puzzle', style: Workshop.display(24, theme: _t)),
              const SizedBox(height: 10),
              Text(
                'Enter a seed code — the same code always builds the same puzzle. Share codes with friends!',
                style: Workshop.body(14, theme: _t),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.black.withValues(alpha: 0.3),
                  border: Border.all(
                      color: _t.accent.withValues(alpha: 0.5)),
                ),
                child: TextField(
                  controller: c,
                  keyboardType: TextInputType.number,
                  style: Workshop.body(16, theme: _t),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'e.g. 12345',
                    hintStyle: Workshop.body(14,
                        theme: _t, color: _t.muted),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              WorkshopButton(
                label: 'Play Seed',
                width: 200,
                fontSize: 17,
                theme: _t,
                onTap: () {
                  final seed =
                      int.tryParse(c.text.trim()) ?? DateTime.now().millisecondsSinceEpoch % 100000;
                  Navigator.of(context).pop();
                  widget.audio.gameStart();
                  final d = PipeDifficulty.values[_s.difficulty];
                  _openGame(GameSetup(
                    mode: GameMode.seed,
                    difficulty: d,
                    level: 0,
                    seed: seed,
                    label: 'Seed $seed · ${difficultySpecs[d]!.label}',
                  ));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openGame(GameSetup setup, {VoidCallback? onNext}) {
    // App-scoped music: keep playing across screens. GameScreen switches
    // to the game track on entry; we switch back to menu music on return.
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => GameScreen(
        setup: setup,
        audio: widget.audio,
        settings: _s,
        store: _store,
        onNext: onNext,
      ),
    ))
        .then((_) {
      if (!mounted) return;
      if (_advancing) {
        _advancing = false; // the next board's screen owns the music now
      } else {
        widget.audio.startMenuMusic();
      }
      setState(() {});
    });
  }

  void _showCampaignPicker() {
    widget.audio.click();
    final d = PipeDifficulty.values[_s.difficulty];
    final done = _s.campaignDone[d.index] ?? 0;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
                colors: [_t.bgMid, _t.tileEdge],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            border: Border.all(color: _t.accent, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${difficultySpecs[d]!.label} Campaign',
                  style: Workshop.display(22, theme: _t)),
              const SizedBox(height: 6),
              Text('$done / 60 boards solved',
                  style: Workshop.body(14, theme: _t, color: _t.muted)),
              const SizedBox(height: 12),
              SizedBox(
                height: 300,
                width: 300,
                child: GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8),
                  itemCount: 60,
                  itemBuilder: (_, i) {
                    final solved = i < done;
                    final current = i == done;
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        _openCampaignLevel(d, i);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: solved
                              ? _t.accent.withValues(alpha: 0.35)
                              : (current
                                  ? _t.water.withValues(alpha: 0.25)
                                  : _t.tile.withValues(alpha: 0.35)),
                          border: Border.all(
                            color: current
                                ? _t.accentLight
                                : _t.accent.withValues(alpha: 0.4),
                            width: current ? 2.5 : 1.5,
                          ),
                        ),
                        child: Text(
                          solved ? '✓' : '${i + 1}',
                          style: Workshop.label(15, theme: _t),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              WorkshopButton(
                  label: 'Close',
                  width: 160,
                  fontSize: 16,
                  theme: _t,
                  onTap: () {
                    widget.audio.click();
                    Navigator.of(context).pop();
                  }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final dailyDone = _s.dailyDoneToday(DateTime.now());
    return WorkshopBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Logo.
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: t.accent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          offset: const Offset(0, 8),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/pipeconnect_logo.png',
                        fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 14),
                  Text('Pipe Connect',
                      style: Workshop.display(44, theme: t)),
                  Text('TWIST · FLOW · WIN',
                      style: Workshop.label(12, theme: t)),
                  const SizedBox(height: 22),
                  WorkshopButton(
                      label: '🔧  Campaign',
                      onTap: _showCampaignPicker,
                      theme: t,
                      width: 260),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      WorkshopButton(
                        label: dailyDone ? '✓ Daily' : '📅 Daily',
                        width: 150,
                        fontSize: 16,
                        theme: t,
                        onTap: _playDaily,
                      ),
                      const SizedBox(width: 10),
                      WorkshopButton(
                        label: '🎲 Seed',
                        width: 150,
                        fontSize: 16,
                        theme: t,
                        onTap: _playSeed,
                      ),
                    ],
                  ),
                  if (_s.dailyStreak > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('🔥 Daily streak: ${_s.dailyStreak}',
                          style: Workshop.label(13, theme: t)),
                    ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProScreen(
                          audio: widget.audio,
                          settings: _s,
                          store: _store,
                        ),
                      ));
                    },
                    child: Container(
                      width: 260,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(colors: [
                          t.accent.withValues(alpha: 0.9),
                          t.tileEdge,
                        ]),
                        border:
                            Border.all(color: t.accentLight, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _s.isPro ? '✦  PRO ACTIVE' : '✦  Get PRO',
                        style: Workshop.label(17,
                            theme: t, color: t.tileEdge),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _DifficultyCard(theme: t),
                  const SizedBox(height: 14),
                  _ThemeCard(theme: t),
                  const SizedBox(height: 14),
                  _NameCard(theme: t),
                  const SizedBox(height: 14),
                  _SupportCard(theme: t, store: _store),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      WorkshopIcon(
                        theme: t,
                        icon: Icons.share,
                        label: 'Share',
                        onTap: () async {
                          widget.audio.click();
                          await Share.share(
                              'Play Pipe Connect with me! Twist the pipes, feed every endpoint. $_storeUrl');
                        },
                      ),
                      const SizedBox(width: 22),
                      WorkshopIcon(
                        theme: t,
                        icon: Icons.star_rate,
                        label: 'Rate',
                        onTap: () async {
                          widget.audio.click();
                          await _requestReview();
                        },
                      ),
                      const SizedBox(width: 22),
                      WorkshopIcon(
                        theme: t,
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: () async {
                          widget.audio.click();
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              audio: widget.audio,
                              settings: _s,
                            ),
                          ));
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(width: 26),
                      WorkshopIcon(
                        theme: t,
                        icon: Icons.help_outline,
                        label: 'How to Play',
                        onTap: () {
                          widget.audio.click();
                          _showHowTo(context, t);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_s.boardsSolved > 0)
                    Text(
                      'Boards solved: ${_s.boardsSolved}${_s.bestTwists > 0 ? '   •   Best: ${_s.bestTwists} twists' : ''}',
                      style: Workshop.label(12, theme: t),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/wajiha_logo.png',
                          width: 22, height: 22, fit: BoxFit.contain),
                      const SizedBox(width: 8),
                      Text('Credits: WAJIHA',
                          style: Workshop.label(12, theme: t)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHowTo(BuildContext context, PipeThemeDef t) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
                colors: [t.bgMid, t.tileEdge],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            border: Border.all(color: t.accent, width: 3),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('How to Play',
                    style: Workshop.display(24, theme: t)),
                const SizedBox(height: 12),
                for (final line in [
                  '• Tap any pipe to twist it 90°.',
                  '• Connect the pump to every glowing endpoint.',
                  '• Connected pipes light up as water flows — so satisfying.',
                  '• The pump can\'t be twisted. Plan around it!',
                  '• Stuck? The 💡 hint button highlights a wrong pipe.',
                  '• Campaign: 60 boards per difficulty. Daily: a fresh puzzle every day. Seed: replay any code.',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(line, style: Workshop.body(14, theme: t)),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: WorkshopButton(
                    label: 'Got it!',
                    width: 180,
                    fontSize: 16,
                    theme: t,
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Difficulty tiers with PRO lock on Hard.
class _DifficultyCard extends StatelessWidget {
  final PipeThemeDef theme;
  const _DifficultyCard({required this.theme});

  static const difficulties = ['Easy', 'Medium', 'Hard'];

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    return WorkshopCard(
      theme: theme,
      title: 'Difficulty',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int d = 0; d < 3; d++)
                WorkshopChip(
                  theme: theme,
                  label: '${d == 2 && !s.isPro ? '🔒 ' : ''}${difficulties[d]}',
                  selected: s.difficulty == d,
                  onTap: () async {
                    audio.click();
                    if (d == 2 && !s.isPro) {
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProScreen(
                          audio: audio,
                          settings: s,
                          store: screen._store,
                        ),
                      ));
                      return;
                    }
                    s.setDifficulty(d);
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            difficultySpecs[PipeDifficulty.values[s.difficulty]]!.blurb,
            style: Workshop.body(13, theme: theme, color: theme.muted),
          ),
          const SizedBox(height: 4),
          for (int d = 0; d < 3; d++)
            Text(
              '${d == s.difficulty ? '▶ ' : ''}${difficulties[d]}: ${s.campaignDone[d] ?? 0}/60 boards',
              style: Workshop.body(12,
                  theme: theme,
                  color: d == s.difficulty ? theme.text : theme.muted),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Theme + pipe-style pickers with PRO locks.
class _ThemeCard extends StatelessWidget {
  final PipeThemeDef theme;
  const _ThemeCard({required this.theme});

  Future<void> _goPro(BuildContext context, _MenuScreenState screen) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProScreen(
        audio: screen.widget.audio,
        settings: screen._s,
        store: screen._store,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    final isPro = s.isPro;
    return WorkshopCard(
      theme: theme,
      title: 'Workshop Style',
      child: Column(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final th in PipeThemes.all)
                _ThemeTile(
                  theme: theme,
                  th: th,
                  selected: s.themeId == th.id,
                  locked: PipeThemes.isProTheme(th.id) && !isPro,
                  onTap: () {
                    audio.click();
                    if (PipeThemes.isProTheme(th.id) && !isPro) {
                      _goPro(context, screen);
                      return;
                    }
                    s.setTheme(th.id);
                  },
                ),
              _ThemeTile(
                theme: theme,
                th: s.customTheme,
                selected: s.themeId == 'custom',
                locked: !isPro,
                custom: true,
                onTap: () {
                  audio.click();
                  if (!isPro) {
                    _goPro(context, screen);
                    return;
                  }
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CustomThemeScreen(
                      audio: audio,
                      settings: s,
                    ),
                  ));
                },
              ),
            ],
          ),
          if (!isPro)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '🔒 ${PipeThemes.all.length - PipeThemes.freeThemeIds.length} more themes in PRO',
                style: Workshop.label(12, theme: theme),
              ),
            ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child:
                Text('Pipe style:', style: Workshop.body(15, theme: theme)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (int i = 0; i < PipeStyles.names.length; i++)
                WorkshopChip(
                  theme: theme,
                  label:
                      '${PipeStyles.isPro(i) && !isPro ? '🔒 ' : ''}${PipeStyles.names[i]}',
                  selected: s.pipeStyle == i,
                  onTap: () {
                    audio.click();
                    if (PipeStyles.isPro(i) && !isPro) {
                      _goPro(context, screen);
                      return;
                    }
                    s.setPipeStyle(i);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final PipeThemeDef theme;
  final PipeThemeDef th;
  final bool selected;
  final bool locked;
  final bool custom;
  final VoidCallback onTap;
  const _ThemeTile({
    required this.theme,
    required this.th,
    required this.selected,
    required this.locked,
    required this.onTap,
    this.custom = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 96,
            padding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: th.tileEdge.withValues(alpha: 0.7),
              border: Border.all(
                color: selected
                    ? th.accentLight
                    : th.accent.withValues(alpha: 0.35),
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: th.pipe,
                            border: Border.all(
                                color: th.accentLight, width: 1))),
                    const SizedBox(width: 4),
                    Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: th.water,
                            border: Border.all(
                                color: th.accentLight, width: 1))),
                    const SizedBox(width: 4),
                    Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: th.endpoint,
                            border: Border.all(
                                color: th.accentLight, width: 1))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  custom ? '🎨 My Creation' : th.name,
                  style: Workshop.label(10, theme: th),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (locked)
            Container(
              width: 96,
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.black.withValues(alpha: 0.55),
              ),
              child: Icon(Icons.lock,
                  color: theme.accentLight, size: 22),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Rename the plumber.
class _NameCard extends StatelessWidget {
  final PipeThemeDef theme;
  const _NameCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    return WorkshopCard(
      theme: theme,
      title: 'Plumber Name',
      child: Column(
        children: [
          _NameField(
            theme: theme,
            initial: s.playerNames.first,
            onDone: (v) => s.setPlayerName(v),
          ),
          const SizedBox(height: 8),
          Text(
            'Your name shows beside every status line.',
            style: Workshop.body(12,
                theme: theme, color: theme.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NameField extends StatefulWidget {
  final PipeThemeDef theme;
  final String initial;
  final ValueChanged<String> onDone;
  const _NameField(
      {required this.theme, required this.initial, required this.onDone});

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _c;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
    _focus = FocusNode();
    // Commit on focus loss so the name is never silently dropped.
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onDone(_c.text);
    });
  }

  @override
  void didUpdateWidget(covariant _NameField old) {
    super.didUpdateWidget(old);
    if (old.initial != widget.initial && _c.text != widget.initial) {
      _c.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withValues(alpha: 0.3),
        border:
            Border.all(color: widget.theme.accent.withValues(alpha: 0.5)),
      ),
      child: TextField(
        controller: _c,
        focusNode: _focus,
        style: Workshop.body(15, theme: widget.theme),
        maxLength: 14,
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
          hintText: 'Your name',
          hintStyle: Workshop.body(14,
              theme: widget.theme, color: widget.theme.muted),
        ),
        // Save on EVERY keystroke: names persist even if the app is killed
        // mid-typing. Storage is a single order-safe JSON string (never a
        // StringList — Android scrambles those).
        onChanged: widget.onDone,
        onSubmitted: widget.onDone,
        onEditingComplete: () => widget.onDone(_c.text),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Tip jar (IAP).
class _SupportCard extends StatelessWidget {
  final PipeThemeDef theme;
  final StoreService store;
  const _SupportCard({required this.theme, required this.store});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final audio = screen.widget.audio;
    return WorkshopCard(
      theme: theme,
      title: 'Support Wajiha',
      child: Column(
        children: [
          Text(
            'Pipe Connect is 100% free. If it made you smile, a small tip keeps the workshop humming!',
            style: Workshop.body(14, theme: theme),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Builder(builder: (_) {
            final tips = [
              store.coffeeProduct,
              store.chocolateProduct,
            ].whereType<ProductDetails>().toList();
            if (!store.storeReady) {
              return Text(
                store.error ?? 'Loading…',
                style: Workshop.body(13,
                    theme: theme, color: theme.muted),
                textAlign: TextAlign.center,
              );
            }
            if (tips.isEmpty) {
              return Text('Tips coming soon.',
                  style: Workshop.body(13,
                      theme: theme, color: theme.muted));
            }
            return Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final p in tips)
                  WorkshopChip(
                    theme: theme,
                    label: p.id == StoreService.chocolateId
                        ? '🍫 ${p.price}'
                        : '☕ ${p.price}',
                    selected: false,
                    onTap: () {
                      audio.click();
                      store.buyTip(p);
                    },
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
