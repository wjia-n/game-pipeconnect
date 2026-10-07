import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Pipe Connect — twist the pipes, light up the flow. 🔧
class PipeConnectScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;

  const PipeConnectScreen(
      {super.key, required this.players, required this.callbacks});

  @override
  State<PipeConnectScreen> createState() => _PipeConnectScreenState();
}

const _rot = {
  'H': 'V', 'V': 'H',
  '1': '2', '2': '3', '3': '4', '4': '1',
  '5': '6', '6': '7', '7': '8', '8': '5',
  '+': '+', 'P': 'P',
  'a': 'b', 'b': 'c', 'c': 'd', 'd': 'a',
  'e': 'f', 'f': 'g', 'g': 'h', 'h': 'e',
};

const _open = {
  'H': {'E', 'W'}, 'V': {'N', 'S'},
  '1': {'N', 'E'}, '2': {'E', 'S'}, '3': {'S', 'W'}, '4': {'W', 'N'},
  '5': {'N', 'E', 'S'}, '6': {'E', 'S', 'W'},
  '7': {'S', 'W', 'N'}, '8': {'W', 'N', 'E'},
  '+': {'N', 'E', 'S', 'W'}, 'P': {'N', 'E', 'S', 'W'},
  'a': {'N'}, 'b': {'E'}, 'c': {'S'}, 'd': {'W'},
  'e': {'N'}, 'f': {'E'}, 'g': {'S'}, 'h': {'W'},
};

const _dxy = {
  'N': [-1, 0],
  'E': [0, 1],
  'S': [1, 0],
  'W': [0, -1]
};
const _opp = {'N': 'S', 'E': 'W', 'S': 'N', 'W': 'E'};

class _PipeConnectScreenState extends State<PipeConnectScreen> {
  int? _level;
  List<String> _grid = []; // flat chars
  int _n = 0;
  int _moves = 0;
  bool _over = false;
  Set<int> _done = {};
  SharedPreferences? _prefs;

  Set<int> _connected = {};
  Set<int> _shown = {};
  final List<int> _queue = [];
  Timer? _flowTimer;
  final Map<int, int> _pops = {}; // tile -> pop animation key

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      _prefs = p;
      setState(() {
        _done = (p.getStringList('pipeconnect_done') ?? [])
            .map(int.parse)
            .toSet();
      });
      final cur = p.getInt('pipeconnect_current');
      if (cur != null && cur >= 0 && cur < _pcLevels.length) {
        _openLevel(cur, silent: true);
      }
    });
  }

  @override
  void dispose() {
    _flowTimer?.cancel();
    super.dispose();
  }

  void _openLevel(int i, {bool silent = false}) {
    final rows = _pcLevels[i];
    setState(() {
      _level = i;
      _n = rows.length;
      _grid = rows.join().split('');
      _moves = 0;
      _over = false;
      _connected = {};
      _shown = {};
      _queue.clear();
      _pops.clear();
    });
    _prefs?.setInt('pipeconnect_current', i);
    if (!silent) Sfx.click();
    _updateFlow();
  }

  int _pumpIndex() => _grid.indexOf('P');

  Set<int> _computeConnected() {
    final start = _pumpIndex();
    final seen = {start};
    final stack = [start];
    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      final r = cur ~/ _n, c = cur % _n;
      for (final d in _open[_grid[cur]]!) {
        final dr = _dxy[d]![0], dc = _dxy[d]![1];
        final nr = r + dr, nc = c + dc;
        if (nr < 0 || nr >= _n || nc < 0 || nc >= _n) continue;
        final nb = nr * _n + nc;
        if (seen.contains(nb)) continue;
        if (_open[_grid[nb]]!.contains(_opp[d])) {
          seen.add(nb);
          stack.add(nb);
        }
      }
    }
    return seen;
  }

  void _updateFlow() {
    final now = _computeConnected();
    final fresh = now.difference(_connected);
    _connected = now;
    _shown.removeWhere((c) => !_connected.contains(c));
    for (final c in fresh) {
      if (!_shown.contains(c) && !_queue.contains(c)) _queue.add(c);
    }
    _flowTimer ??= Timer.periodic(const Duration(milliseconds: 55), (_) {
      if (!mounted) return;
      if (_queue.isEmpty) {
        _flowTimer?.cancel();
        _flowTimer = null;
        return;
      }
      setState(() => _shown.add(_queue.removeAt(0)));
    });
    _checkWin();
  }

  bool _isEndpoint(String ch) => 'abcd'.contains(ch);

  void _checkWin() {
    if (_over || _level == null || _moves == 0) return;
    for (var i = 0; i < _grid.length; i++) {
      if (_isEndpoint(_grid[i]) && !_connected.contains(i)) return;
    }
    setState(() => _over = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || _level == null || !_over) return;
      Sfx.win();
      _done.add(_level!);
      _prefs?.setStringList(
          'pipeconnect_done', _done.map((e) => e.toString()).toList());
      _prefs?.setInt('pipeconnect_current',
          _level! + 1 < _pcLevels.length ? _level! + 1 : _level!);
      final isLast = _level! == _pcLevels.length - 1;
      widget.callbacks.finish(
        headline: 'Plumbing perfection! 🔧✨',
        subline: isLast
            ? 'All 15 boards flowing! You are certified Pipe Royalty 👑'
            : 'Every drop delivered! Board ${_level! + 2} awaits 🚰',
      );
    });
  }

  void _tapTile(int i) {
    if (_over || _level == null || _grid[i] == 'P') return;
    setState(() {
      _grid[i] = _rot[_grid[i]]!;
      _moves++;
      _pops[i] = (_pops[i] ?? 0) + 1;
    });
    Sfx.tap();
    _updateFlow();
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    if (_level == null) return _selectScreen(t);
    return _gameScreen(t);
  }

  Widget _selectScreen(GameTheme t) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pick a pipeline 🔧',
              style: TextStyle(
                  color: t.text, fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${_done.length}/${_pcLevels.length} boards flowing',
              style: TextStyle(color: t.muted, fontSize: 14)),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12),
              itemCount: _pcLevels.length,
              itemBuilder: (_, i) {
                final done = _done.contains(i);
                final n = _pcLevels[i].length;
                return GestureDetector(
                  onTap: () => _openLevel(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: done
                          ? t.primary.withValues(alpha: 0.22)
                          : t.surface,
                      borderRadius: t.radius,
                      border: Border.all(
                          color: t.primary.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(done ? '✅' : '🔧',
                            style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 4),
                        Text('Board ${i + 1}',
                            style: TextStyle(
                                color: t.text,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                        Text('$n×$n grid',
                            style:
                                TextStyle(color: t.muted, fontSize: 11)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _gameScreen(GameTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              _iconBtn(t, '◀️', () => setState(() => _level = null)),
              const SizedBox(width: 8),
              Text('Board ${_level! + 1}',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
              const Spacer(),
              Text('$_moves twists',
                  style: TextStyle(color: t.muted, fontSize: 13)),
              const SizedBox(width: 8),
              _iconBtn(t, '🔄', () => _openLevel(_level!)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Tap pipes to twist them — feed every 💡!',
              style: TextStyle(color: t.muted, fontSize: 13)),
          const SizedBox(height: 10),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: t.surface.withValues(alpha: 0.5),
                    borderRadius: t.radius,
                    border: Border.all(
                        color: t.primary.withValues(alpha: 0.3), width: 2),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _n,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4),
                    itemCount: _grid.length,
                    itemBuilder: (_, i) => _tile(i, t),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _iconBtn(GameTheme t, String emoji, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: t.surface,
            borderRadius: t.radius,
            border: Border.all(color: t.primary.withValues(alpha: 0.3))),
        alignment: Alignment.center,
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
    );
  }

  Widget _tile(int i, GameTheme t) {
    final ch = _grid[i];
    final lit = _shown.contains(i);
    final isPump = ch == 'P';
    final isEnd = _isEndpoint(ch);
    return GestureDetector(
      onTap: () => _tapTile(i),
      child: TweenAnimationBuilder<double>(
        key: ValueKey(_pops[i] ?? 0),
        tween: Tween(begin: 0.82, end: 1.0),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        builder: (_, s, _) => Transform.scale(
          scale: s,
          child: Container(
            decoration: BoxDecoration(
              color: lit
                  ? t.accent.withValues(alpha: 0.28)
                  : t.background.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              boxShadow: lit
                  ? [
                      BoxShadow(
                          color: t.accent.withValues(alpha: 0.5),
                          blurRadius: 10)
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                    painter: _PipePainter(
                        openings: _open[ch]!,
                        lit: lit,
                        pipe: lit ? t.accent : t.muted.withValues(alpha: 0.55),
                        glow: t.accent)),
                if (isPump)
                  const Text('💧', style: TextStyle(fontSize: 20))
                else if (isEnd)
                  Text(lit ? '💡' : '🔌',
                      style: const TextStyle(fontSize: 18)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PipePainter extends CustomPainter {
  final Set<String> openings;
  final bool lit;
  final Color pipe;
  final Color glow;

  _PipePainter(
      {required this.openings,
      required this.lit,
      required this.pipe,
      required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final w = size.width * 0.26;
    final paint = Paint()
      ..color = pipe
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    if (lit) {
      paint
        ..color = glow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    }
    for (final d in openings) {
      final end = switch (d) {
        'N' => Offset(c.dx, 0),
        'S' => Offset(c.dx, size.height),
        'E' => Offset(size.width, c.dy),
        _ => Offset(0, c.dy),
      };
      canvas.drawLine(c, end, paint);
    }
    canvas.drawCircle(
        c, w * 0.62, Paint()..color = lit ? glow : pipe);
  }

  @override
  bool shouldRepaint(covariant _PipePainter old) =>
      old.openings != openings || old.lit != lit || old.pipe != pipe;
}
// ===== PIPE CONNECT LEVELS =====
const _pcLevels = [
  ['h1Hb4','h8e+7','a+67f','eP21g','4fg8h'], // 5x5
  ['HeVPc','7gd+e','e2V7f','gh4+3','8f4fe'], // 5x5
  ['16gVd','23HfH','4f8+2','feh+c','2HVPg'], // 5x5
  ['cHPggf','e7+H73','f76571','42fHhg','e4a47+','HH4363'], // 6x6
  ['7fef3d','7g6HdV','gH6P61','g2778h','g8574h','h6hg77'], // 6x6
  ['e2e38e','Hf7V43','g7P87d','f6+4f3','14H1Vf','dh6d21'], // 6x6
  ['34VHVP2','e7+hH7a','He3hV+2','7gHVV5h','V4e3h+b','8cHH67V','14eH42g'], // 7x7
  ['d6hf453','e64ef26','g76g87g','VVc3d5H','88+4hg4','7g1g68g','PVVH6Hg'], // 7x7
  ['4eVe6f3','ef78e4H','67eae62','d54265f','h6V56P7','7He6fHe','5bg4f5h'], // 7x7
  ['efef6h85','VVVHg75g','2575Ve1e','h65Hhh+3','f+7Vaf5+','h7g2H86c','g7P8fe14','dH7HH1Vg'], // 8x8
  ['2PHHchaf','b5H78+51','f+egH848','3+fg6h4h','e7g4+H32','e86hH8V2','gg1V4dHH','h371h7hg'], // 8x8
  ['g43f55g6','5HH6+4+f','e+6Vh4ge','d+begehh','f+H4VHeV','fHgg755e','8+P++V7f','ghce4a2e'], // 8x8
  ['4Pf7gh7g','e58f26V7','17857bgg','eHb8H66d','e72V6f75','e+c77Hg4','Vge62218','38f13e3f'], // 8x8
  ['Hh3hhdfe','h+766+1V','12gdV6hV','gV5eg+5P','6+Vc8816','51H16egV','hHH4Hg78','g6V2efch'], // 8x8
  ['5e71V5H4','c673ePfV','Hg4g5+ge','48V756f2','He47aV54','4fVg88c4','52e27843','V8feb3h5'], // 8x8
];
