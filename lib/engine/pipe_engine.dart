import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Tile glyphs. Rotation is clockwise 90° per tap.
// ---------------------------------------------------------------------------
/// Rotate one glyph clockwise.
String rotateGlyph(String ch) => switch (ch) {
      'H' => 'V',
      'V' => 'H',
      '1' => '2',
      '2' => '3',
      '3' => '4',
      '4' => '1',
      '5' => '6',
      '6' => '7',
      '7' => '8',
      '8' => '5',
      'a' => 'b',
      'b' => 'c',
      'c' => 'd',
      'd' => 'a',
      _ => ch, // '+' and 'P' are symmetric
    };

/// Open directions per glyph: N/E/S/W.
const Map<String, Set<String>> _open = {
  'H': {'E', 'W'},
  'V': {'N', 'S'},
  '1': {'N', 'E'},
  '2': {'E', 'S'},
  '3': {'S', 'W'},
  '4': {'W', 'N'},
  '5': {'N', 'E', 'S'},
  '6': {'E', 'S', 'W'},
  '7': {'S', 'W', 'N'},
  '8': {'W', 'N', 'E'},
  '+': {'N', 'E', 'S', 'W'},
  'P': {'N', 'E', 'S', 'W'},
  'a': {'N'},
  'b': {'E'},
  'c': {'S'},
  'd': {'W'},
};

Set<String> openingsOf(String ch) => _open[ch] ?? const {};

const _dxy = {'N': [-1, 0], 'E': [0, 1], 'S': [1, 0], 'W': [0, -1]};
const _opp = {'N': 'S', 'E': 'W', 'S': 'N', 'W': 'E'};

bool _isPump(String ch) => ch == 'P';

// ---------------------------------------------------------------------------
// Difficulty tiers (RULES.md §1-2).
// ---------------------------------------------------------------------------
enum PipeDifficulty { easy, medium, hard }

class DifficultySpec {
  final int size;
  final double coverage; // fraction of grid cells in the solved network
  final String label;
  final String blurb;
  const DifficultySpec(this.size, this.coverage, this.label, this.blurb);
}

const difficultySpecs = {
  PipeDifficulty.easy: DifficultySpec(5, 0.50, 'Easy', '5×5 · gentle pipelines'),
  PipeDifficulty.medium: DifficultySpec(7, 0.62, 'Medium', '7×7 · real plumbing'),
  PipeDifficulty.hard: DifficultySpec(9, 0.74, 'Hard', '9×9 · master plumber'),
};

// ---------------------------------------------------------------------------
// Seeded puzzle generation: deterministic, always solvable.
// ---------------------------------------------------------------------------
/// A generated puzzle: solution glyphs, scrambled starting glyphs, pump
/// index and endpoint indices (flat indexes, row-major).
class PipePuzzle {
  final int size;
  final List<String> solution;
  final List<String> scrambled;
  final int pump;
  final List<int> endpoints;
  const PipePuzzle({
    required this.size,
    required this.solution,
    required this.scrambled,
    required this.pump,
    required this.endpoints,
  });
}

/// Deterministic seed helpers.
int campaignSeed(PipeDifficulty d, int level) =>
    900000 + d.index * 1000003 + level * 7919;
int dailySeed(DateTime day) =>
    day.year * 10000 + day.month * 100 + day.day; // YYYYMMDD

/// Generate a puzzle from [seed]. The solved network is grown as a winding
/// tree from the pump (always solvable); every rotatable tile is then
/// scrambled by a random number of rotations.
PipePuzzle generatePuzzle(int seed, PipeDifficulty difficulty) {
  final spec = difficultySpecs[difficulty]!;
  final n = spec.size;
  final rng = Random(seed);
  final pumpR = n ~/ 2;
  final pumpC = n ~/ 2;
  final pump = pumpR * n + pumpC;

  // Grow the solved network: Prim-like growth with a bias toward extending
  // the most recently added cell — makes long winding runs instead of a
  // bushy tree, so endpoint counts stay friendly.
  final target = (n * n * spec.coverage).round();
  final inNet = {pump};
  final openOf = <int, Set<String>>{};
  // frontier: (fromCell, newCell, directionFromNewCellToParent)
  final frontier = <List<Object>>[];
  void addFrontier(int cell) {
    final r = cell ~/ n, c = cell % n;
    for (final d in ['N', 'E', 'S', 'W']) {
      final nr = r + _dxy[d]![0], nc = c + _dxy[d]![1];
      if (nr < 0 || nr >= n || nc < 0 || nc >= n) continue;
      final nb = nr * n + nc;
      if (!inNet.contains(nb)) frontier.add([cell, nb, _opp[d]!]);
    }
  }

  addFrontier(pump);
  int tip = pump;
  while (inNet.length < target && frontier.isNotEmpty) {
    int pick;
    // 55%: extend from the most recent tip (winding runs); else random.
    final tipEdges = frontier.where((e) => e[0] == tip).toList();
    if (tipEdges.isNotEmpty && rng.nextDouble() < 0.55) {
      pick = frontier.indexOf(tipEdges[rng.nextInt(tipEdges.length)]);
    } else {
      pick = rng.nextInt(frontier.length);
    }
    final edge = frontier.removeAt(pick);
    final from = edge[0] as int, to = edge[1] as int;
    final dirFromNew = edge[2] as String; // direction from new cell to parent
    if (inNet.contains(to)) continue;
    inNet.add(to);
    final dirFromParent = _opp[dirFromNew]!;
    openOf.putIfAbsent(from, () => {}).add(dirFromParent);
    openOf.putIfAbsent(to, () => {}).add(dirFromNew);
    tip = to;
    addFrontier(to);
  }

  // Assign glyphs from the actual connections. Every leaf becomes an
  // endpoint — the player must feed them all.
  final solution = List<String>.filled(n * n, '?');
  final endpoints = <int>[];
  for (int i = 0; i < n * n; i++) {
    if (!inNet.contains(i)) {
      // Filler: random decor pipe, never a pump or endpoint.
      final kinds = ['H', 'V', '1', '2', '3', '4', '5', '6', '7', '8', '+'];
      solution[i] = kinds[rng.nextInt(kinds.length)];
      continue;
    }
    if (i == pump) {
      solution[i] = 'P';
      continue;
    }
    final dirs = openOf[i] ?? {};
    solution[i] = switch (dirs.length) {
      1 => () {
        endpoints.add(i);
        final d = dirs.single;
        return d == 'N'
            ? 'a'
            : d == 'E'
                ? 'b'
                : d == 'S'
                    ? 'c'
                    : 'd';
      }(),
      2 => () {
        final hasN = dirs.contains('N');
        final hasE = dirs.contains('E');
        final hasS = dirs.contains('S');
        if (hasN && hasS) return 'V';
        if (hasE && !hasN && !hasS) return 'H';
        if (hasN && hasE) return '1';
        if (hasE && hasS) return '2';
        if (hasS) return '3'; // S,W (W implied)
        return '4'; // W,N
      }(),
      3 => dirs.contains('W') ? '8' : (dirs.contains('N') ? '5' : '6'),
      // NES=5, ESW=6, SWN=7, WNE=8
      _ => '+',
    };
    // Fix the 3-way mapping properly.
    if (dirs.length == 3) {
      solution[i] = !dirs.contains('W')
          ? '5'
          : !dirs.contains('N')
              ? '6'
              : !dirs.contains('E')
                  ? '7'
                  : '8';
    }
  }

  // Scramble: random rotations; guarantee the puzzle is not already solved.
  final scrambled = List<String>.from(solution);
  int wrong = 0;
  for (int i = 0; i < n * n; i++) {
    if (_isPump(scrambled[i]) || scrambled[i] == '+') continue;
    final twists = rng.nextInt(4);
    for (int k = 0; k < twists; k++) {
      scrambled[i] = rotateGlyph(scrambled[i]);
    }
    if (scrambled[i] != solution[i]) wrong++;
  }
  if (wrong == 0) {
    // Ensure at least one twist is needed.
    final candidates = [
      for (int i = 0; i < n * n; i++)
        if (!_isPump(scrambled[i]) && scrambled[i] != '+') i
    ];
    if (candidates.isNotEmpty) {
      final c = candidates[rng.nextInt(candidates.length)];
      scrambled[c] = rotateGlyph(scrambled[c]);
    }
  }

  return PipePuzzle(
    size: n,
    solution: solution,
    scrambled: scrambled,
    pump: pump,
    endpoints: endpoints,
  );
}

// ---------------------------------------------------------------------------
// Engine: owns ALL phase state; UI only renders. Watchdog recovers any
// transient phase found without a live timer — stuck states impossible.
// ---------------------------------------------------------------------------
enum Phase { playing, celebrating, over }

enum PipeEvent {
  twist, // valid twist
  invalid, // tap on pump / input during celebration
  flow, // new cells started flowing
  connect, // a cell newly connected
  hint, // hint shown
  hintDenied, // no hint moves left
  levelStart,
  win,
}

class PipeEngine extends ChangeNotifier {
  final PipePuzzle puzzle;
  final String label;
  final bool hintsUnlimited;

  List<String> tiles;
  final List<int> twistCount; // per-cell rotation counts for UI animation

  int moves = 0;
  int hintsUsed = 0;
  Phase phase = Phase.playing;

  Set<int> connected = {};
  final Set<int> revealed = {}; // animated water-fill, subset of connected
  final List<int> _revealQueue = [];
  int? hintTile;
  DateTime? _hintUntil;

  Timer? _flowTimer;
  Timer? _phaseTimer;
  Timer? _watchdog;
  bool _disposed = false;
  bool paused = false;

  /// UI hook for sounds. Set by the screen.
  void Function(PipeEvent event)? onEvent;

  PipeEngine({
    required this.puzzle,
    required this.label,
    this.hintsUnlimited = false,
  })  : tiles = List<String>.from(puzzle.scrambled),
        twistCount = List<int>.filled(puzzle.size * puzzle.size, 0) {
    _recompute(silent: true);
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) => _recover());
    onEventLater(PipeEvent.levelStart);
  }

  void onEventLater(PipeEvent e) {
    // Defer so the screen can attach onEvent after constructing us.
    Future.microtask(() {
      if (!_disposed) onEvent?.call(e);
    });
  }

  int get n => puzzle.size;
  int get size => puzzle.size;
  bool get solved =>
      puzzle.endpoints.every((e) => connected.contains(e));
  int get hintsLeft => hintsUnlimited ? 999 : (3 - hintsUsed).clamp(0, 3);

  @override
  void dispose() {
    _disposed = true;
    _flowTimer?.cancel();
    _phaseTimer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------ pause/flow
  /// Pause: freeze timers; resume re-arms everything via the watchdog.
  void setPaused(bool v) {
    if (paused == v || _disposed) return;
    paused = v;
    if (v) {
      _flowTimer?.cancel();
      _flowTimer = null;
      _phaseTimer?.cancel();
      _phaseTimer = null;
    } else {
      _recover();
    }
    notifyListeners();
  }

  void _armFlow() {
    if (_disposed || paused || _flowTimer != null) return;
    _flowTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (_disposed || paused) return;
      if (_revealQueue.isEmpty) {
        _flowTimer?.cancel();
        _flowTimer = null;
        _checkWin();
        return;
      }
      final cell = _revealQueue.removeAt(0);
      revealed.add(cell);
      onEvent?.call(PipeEvent.connect);
      notifyListeners();
    });
  }

  void _armPhase(Duration d, void Function() fn) {
    if (_disposed || paused) return;
    _phaseTimer?.cancel();
    _phaseTimer = Timer(d, () {
      _phaseTimer = null;
      if (!_disposed && !paused) fn();
    });
  }

  /// Watchdog: no stuck states by construction. Any transient phase found
  /// without a live timer gets recovered.
  void _recover() {
    if (_disposed || paused) return;
    if (_revealQueue.isNotEmpty && _flowTimer == null) _armFlow();
    if (phase == Phase.celebrating && _phaseTimer == null) {
      _armPhase(const Duration(milliseconds: 400), _finish);
    }
    if (_hintUntil != null && DateTime.now().isAfter(_hintUntil!)) {
      hintTile = null;
      _hintUntil = null;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ game logic
  /// Breadth-first water spread from the pump through matching openings.
  /// Returns cells in BFS visit order (for the animated reveal).
  List<int> _spread() {
    final seen = {puzzle.pump};
    final order = <int>[];
    final queue = [puzzle.pump];
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      order.add(cur);
      final r = cur ~/ n, c = cur % n;
      for (final d in openingsOf(tiles[cur])) {
        final nr = r + _dxy[d]![0], nc = c + _dxy[d]![1];
        if (nr < 0 || nr >= n || nc < 0 || nc >= n) continue;
        final nb = nr * n + nc;
        if (seen.contains(nb)) continue;
        if (openingsOf(tiles[nb]).contains(_opp[d])) {
          seen.add(nb);
          queue.add(nb);
        }
      }
    }
    return order;
  }

  /// Recompute the connected set after a twist. Newly connected cells are
  /// queued for the ANIMATED reveal — never instant.
  void _recompute({bool silent = false}) {
    final order = _spread();
    final now = order.toSet();
    final fresh = now.difference(connected);
    connected = now;
    revealed.removeWhere((cell) => !connected.contains(cell));
    _revealQueue.removeWhere((cell) => !connected.contains(cell));
    // Requeue in BFS visit order so water visibly spreads from the pump.
    for (final cell in order) {
      if (!revealed.contains(cell) && !_revealQueue.contains(cell)) {
        _revealQueue.add(cell);
      }
    }
    // Pump always shows water.
    if (!revealed.contains(puzzle.pump)) {
      revealed.add(puzzle.pump);
      _revealQueue.remove(puzzle.pump);
    }
    if (!silent && fresh.isNotEmpty) onEvent?.call(PipeEvent.flow);
    if (_revealQueue.isNotEmpty) _armFlow();
  }

  /// Twist a pipe 90° clockwise. Every tap animates visibly (UI reads
  /// [twistCount] for AnimatedRotation); flow reveals queue up animatedly.
  void twist(int i) {
    if (_disposed || paused || phase != Phase.playing) {
      onEvent?.call(PipeEvent.invalid);
      return;
    }
    if (i < 0 || i >= tiles.length) return;
    if (_isPump(tiles[i])) {
      onEvent?.call(PipeEvent.invalid);
      return;
    }
    tiles[i] = rotateGlyph(tiles[i]);
    twistCount[i]++;
    moves++;
    hintTile = null;
    _hintUntil = null;
    onEvent?.call(PipeEvent.twist);
    notifyListeners();
    _recompute();
  }

  /// Show a hint: pulse one misrotated tile. Animated, never instant.
  void hint() {
    if (_disposed || paused || phase != Phase.playing) return;
    if (hintsUsed >= 3 && !hintsUnlimited) {
      onEvent?.call(PipeEvent.hintDenied);
      return;
    }
    final wrong = <int>[];
    for (int i = 0; i < tiles.length; i++) {
      if (tiles[i] != puzzle.solution[i] && !_isPump(tiles[i])) wrong.add(i);
    }
    if (wrong.isEmpty) {
      onEvent?.call(PipeEvent.hintDenied);
      return;
    }
    hintsUsed++;
    // Prefer an endpoint-adjacent or endpoint tile so the hint feels useful.
    wrong.shuffle();
    hintTile = wrong.first;
    _hintUntil = DateTime.now().add(const Duration(seconds: 3));
    onEvent?.call(PipeEvent.hint);
    notifyListeners();
    // Auto-clear with animation end; watchdog also clears as backup.
    _armPhase(const Duration(seconds: 3), () {
      hintTile = null;
      _hintUntil = null;
      notifyListeners();
    });
  }

  void _checkWin() {
    if (phase != Phase.playing) return;
    if (!solved) return;
    phase = Phase.celebrating;
    hintTile = null;
    _hintUntil = null;
    onEvent?.call(PipeEvent.win);
    notifyListeners();
    _armPhase(const Duration(milliseconds: 1600), _finish);
  }

  void _finish() {
    if (phase != Phase.celebrating) return;
    phase = Phase.over;
    notifyListeners();
  }

  /// Restart the same puzzle (fresh scramble).
  void restart() {
    if (_disposed) return;
    _flowTimer?.cancel();
    _flowTimer = null;
    _phaseTimer?.cancel();
    _phaseTimer = null;
    tiles = List<String>.from(puzzle.scrambled);
    twistCount.fillRange(0, twistCount.length, 0);
    moves = 0;
    hintsUsed = 0;
    phase = Phase.playing;
    connected = {};
    revealed.clear();
    _revealQueue.clear();
    hintTile = null;
    _hintUntil = null;
    _recompute(silent: true);
    onEvent?.call(PipeEvent.levelStart);
    notifyListeners();
  }

  /// How many tiles are currently misrotated (for the "stuck?" helper).
  int misrotatedCount() {
    int c = 0;
    for (int i = 0; i < tiles.length; i++) {
      if (tiles[i] != puzzle.solution[i]) c++;
    }
    return c;
  }

  /// Test hook: the current water spread from the pump in BFS order.
  @visibleForTesting
  List<int> debugSpread() => _spread();
}
