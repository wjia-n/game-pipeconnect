import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/pipe_engine.dart';
import '../theme/pipe_themes.dart';

/// Persisted settings + stats for Pipe Connect. Survives app restarts.
///
/// Stores: audio toggles, the player name, theme/pipe-style choices (incl.
/// custom theme colors), difficulty, Pro unlock state, campaign progress,
/// daily-challenge streak, and lifetime stats.
class PipeSettings extends ChangeNotifier {
  static const _kMusic = 'pipeconnect_music_on';
  static const _kSfx = 'pipeconnect_sfx_on';
  static const _kVolume = 'pipeconnect_volume';
  static const _kDifficulty = 'pipeconnect_difficulty'; // 0 easy, 1 med, 2 hard
  static const _kNamesLegacy = 'pipeconnect_player_names'; // legacy StringSet
  /// Order-safe player-name storage: a single JSON string. Android's
  /// SharedPreferences stores StringLists as an unordered StringSet, so a
  /// StringList must NEVER be used for ordered data. Never call setStringList.
  static const _kNamesJson = 'pipeconnect_player_names_json';
  static const _kTheme = 'pipeconnect_theme_id';
  static const _kPipeStyle = 'pipeconnect_pipe_style';
  static const _kCampaignLegacy = 'pipeconnect_done'; // legacy StringList key
  static const _kCampaignJson = 'pipeconnect_campaign_json';
  static const _kDailyJson = 'pipeconnect_daily_json';
  static const _kBoards = 'pipeconnect_boards_solved';
  static const _kBestTwists = 'pipeconnect_best_twists';
  static const _kIsPro = 'pipeconnect_is_pro';
  static const _kCustomPrefix = 'pipeconnect_custom_';

  static const defaultName = 'Plumber';

  /// Encode player names as one JSON string (order-preserving).
  static String encodePlayerNames(List<String> names) => jsonEncode(names);

  static String _cleanName(int i, Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultName : s;
  }

  /// Decode persisted names; falls back to defaults on missing/corrupt data.
  static List<String> decodePlayerNames(String? raw) {
    if (raw == null) return [defaultName];
    try {
      final d = jsonDecode(raw);
      if (d is List && d.isNotEmpty) {
        return [_cleanName(0, d[0])];
      }
    } catch (_) {}
    return [defaultName];
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  int difficulty = 1; // medium default
  List<String> playerNames = [defaultName];
  String themeId = 'copper';
  int pipeStyle = 0;
  bool isPro = true; // everything unlocked — no Pro version

  /// Campaign progress: highest COMPLETED level per difficulty (0-based
  /// count). JSON: {"0": 12, "1": 5, "2": 0}.
  Map<int, int> campaignDone = {0: 0, 1: 0, 2: 0};

  /// Daily challenge: last completed date (YYYY-MM-DD) + streak.
  String? dailyDoneDate;
  int dailyStreak = 0;

  int boardsSolved = 0;
  int bestTwists = 0; // fewest twists for any board (0 = none yet)

  /// Custom theme colors (ARGB ints).
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'bgDeep': 0xFF2B1A10,
    'bgMid': 0xFF4A2E1A,
    'tile': 0xFF5C3A21,
    'tileEdge': 0xFF241309,
    'pipe': 0xFF9AA3AD,
    'water': 0xFF4FB3E8,
    'endpoint': 0xFFC9A227,
    'accent': 0xFFC9A227,
    'accentLight': 0xFFE8CE7A,
    'text': 0xFFF5EFE0,
  };

  PipeThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return PipeThemeDef(
      id: 'custom',
      name: 'My Creation',
      bgDeep: c('bgDeep'),
      bgMid: c('bgMid'),
      tile: c('tile'),
      tileEdge: c('tileEdge'),
      pipe: c('pipe'),
      pipeHi: c('pipe').withValues(alpha: 0.35),
      water: c('water'),
      waterHi: c('water').withValues(alpha: 0.45),
      endpoint: c('endpoint'),
      pump: c('accent'),
      accent: c('accent'),
      accentLight: c('accentLight'),
      text: c('text'),
      muted: c('text').withValues(alpha: 0.6),
    );
  }

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    difficulty = (p.getInt(_kDifficulty) ?? 1).clamp(0, 2);
    // Player names: prefer the order-safe JSON key. One-time migration from
    // the legacy StringList key (may already be scrambled on Android).
    final namesRaw = p.getString(_kNamesJson);
    if (namesRaw != null) {
      playerNames = decodePlayerNames(namesRaw);
    } else {
      final legacy = p.getStringList(_kNamesLegacy);
      playerNames = (legacy != null && legacy.isNotEmpty)
          ? [_cleanName(0, legacy[0])]
          : [defaultName];
    }
    themeId = p.getString(_kTheme) ?? 'copper';
    pipeStyle = (p.getInt(_kPipeStyle) ?? 0).clamp(0, PipeStyles.names.length - 1);
    // Campaign: prefer JSON; migrate the legacy StringList once.
    final campRaw = p.getString(_kCampaignJson);
    if (campRaw != null) {
      try {
        final d = jsonDecode(campRaw);
        if (d is Map) {
          for (final k in ['0', '1', '2']) {
            final v = d[k];
            campaignDone[int.parse(k)] =
                v is int ? v.clamp(0, 60) : 0;
          }
        }
      } catch (_) {}
    } else {
      final legacy = p.getStringList(_kCampaignLegacy);
      if (legacy != null && legacy.isNotEmpty) {
        campaignDone[1] = legacy.length.clamp(0, 60);
      }
    }
    final dailyRaw = p.getString(_kDailyJson);
    if (dailyRaw != null) {
      try {
        final d = jsonDecode(dailyRaw);
        if (d is Map) {
          final dd = d['date'];
          if (dd is String) dailyDoneDate = dd;
          final st = d['streak'];
          if (st is int) dailyStreak = st.clamp(0, 10000);
        }
      } catch (_) {}
    }
    boardsSolved = p.getInt(_kBoards) ?? 0;
    bestTwists = p.getInt(_kBestTwists) ?? 0;
    isPro = true; // everything unlocked
    for (final k in _defaultCustomColors.keys) {
      customColors[k] =
          p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setInt(_kDifficulty, difficulty);
    await p.setString(_kNamesJson, encodePlayerNames(playerNames));
    await p.remove(_kNamesLegacy);
    await p.setString(_kTheme, themeId);
    await p.setInt(_kPipeStyle, pipeStyle);
    await p.setString(
        _kCampaignJson,
        jsonEncode(
            {for (final e in campaignDone.entries) '${e.key}': e.value}));
    await p.remove(_kCampaignLegacy);
    await p.setString(
        _kDailyJson,
        jsonEncode({'date': dailyDoneDate, 'streak': dailyStreak}));
    await p.setInt(_kBoards, boardsSolved);
    await p.setInt(_kBestTwists, bestTwists);
    await p.setBool(_kIsPro, isPro);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || PipeThemes.isProTheme(themeId)) {
      themeId = 'copper';
      changed = true;
    }
    if (PipeStyles.isPro(pipeStyle)) {
      pipeStyle = 0;
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return;
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setDifficulty(int d) async {
    d = d.clamp(0, 2);
    if (!isPro && d > 1) return; // hard mode is a Pro feature
    difficulty = d;
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(String name) async {
    final clean = name.trim();
    playerNames = [clean.isEmpty ? defaultName : clean];
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || PipeThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setPipeStyle(int v) async {
    v = v.clamp(0, PipeStyles.names.length - 1);
    if (!isPro && PipeStyles.isPro(v)) return;
    pipeStyle = v;
    notifyListeners();
    await _save();
  }

  /// Record a solved campaign level: [level] is 0-based; completed count
  /// becomes max(current, level + 1).
  Future<void> recordCampaignWin(PipeDifficulty d, int level,
      {required int twists}) async {
    final key = d.index;
    campaignDone[key] = (campaignDone[key] ?? 0).clamp(0, 60);
    if (level + 1 > campaignDone[key]!) {
      campaignDone[key] = (level + 1).clamp(0, 60);
    }
    boardsSolved++;
    if (bestTwists == 0 || twists < bestTwists) bestTwists = twists;
    notifyListeners();
    await _save();
  }

  /// Record a solved board outside the campaign (daily / seed).
  Future<void> recordBoardWin({required int twists}) async {
    boardsSolved++;
    if (bestTwists == 0 || twists < bestTwists) bestTwists = twists;
    notifyListeners();
    await _save();
  }

  static String dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  /// Record today's daily completion; maintains the streak.
  Future<void> recordDailyWin(DateTime today) async {
    final key = dateKey(today);
    if (dailyDoneDate == key) {
      await _save();
      return;
    }
    final yesterday =
        dateKey(today.subtract(const Duration(days: 1)));
    dailyStreak = (dailyDoneDate == yesterday) ? dailyStreak + 1 : 1;
    dailyDoneDate = key;
    boardsSolved++;
    notifyListeners();
    await _save();
  }

  bool dailyDoneToday(DateTime today) => dailyDoneDate == dateKey(today);

  Future<void> resetProgress() async {
    campaignDone = {0: 0, 1: 0, 2: 0};
    dailyDoneDate = null;
    dailyStreak = 0;
    boardsSolved = 0;
    bestTwists = 0;
    notifyListeners();
    await _save();
  }
}
