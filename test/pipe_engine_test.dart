import 'package:flutter_test/flutter_test.dart';
import 'package:pipeconnect/engine/pipe_engine.dart';
import 'package:pipeconnect/services/settings_service.dart';

void main() {
  group('generator', () {
    test('same seed + difficulty yields the same puzzle', () {
      final a = generatePuzzle(4242, PipeDifficulty.medium);
      final b = generatePuzzle(4242, PipeDifficulty.medium);
      expect(a.scrambled, b.scrambled);
      expect(a.solution, b.solution);
      expect(a.pump, b.pump);
    });

    test('scramble differs from the solution (never pre-solved)', () {
      for (final d in PipeDifficulty.values) {
        for (int seed = 1; seed <= 25; seed++) {
          final p = generatePuzzle(seed, d);
          final wrong = [
            for (int i = 0; i < p.scrambled.length; i++)
              if (p.scrambled[i] != p.solution[i]) i
          ];
          expect(wrong, isNotEmpty,
              reason: 'seed=$seed diff=$d produced a pre-solved board');
        }
      }
    });

    test('solution is connected: every endpoint reachable from the pump', () {
      for (final d in PipeDifficulty.values) {
        final p = generatePuzzle(777, d);
        final engine = PipeEngine(puzzle: p, label: 'test');
        // Temporarily apply the solution to verify reachability.
        engine.tiles = List.of(p.solution);
        final spread = engine.debugSpread();
        for (final e in p.endpoints) {
          expect(spread, contains(e),
              reason: 'endpoint $e unreachable in solution (diff=$d)');
        }
        engine.dispose();
      }
    });

    test('grid sizes match difficulty specs', () {
      expect(generatePuzzle(1, PipeDifficulty.easy).size, 5);
      expect(generatePuzzle(1, PipeDifficulty.medium).size, 7);
      expect(generatePuzzle(1, PipeDifficulty.hard).size, 9);
    });
  });

  group('engine', () {
    test('untwisting back to the solution wins the board', () {
      final p = generatePuzzle(31337, PipeDifficulty.easy);
      final engine = PipeEngine(puzzle: p, label: 'test');
      // Rotate each tile back to its solution glyph.
      for (int i = 0; i < p.scrambled.length; i++) {
        while (engine.tiles[i] != p.solution[i]) {
          engine.twist(i);
        }
      }
      expect(engine.solved, isTrue);
      engine.dispose();
    });

    test('pump cannot be twisted', () {
      final p = generatePuzzle(99, PipeDifficulty.easy);
      final engine = PipeEngine(puzzle: p, label: 'test');
      final before = engine.tiles[p.pump];
      engine.twist(p.pump);
      expect(engine.tiles[p.pump], before);
      expect(engine.moves, 0);
      engine.dispose();
    });

    test('twist counts moves and rotates the glyph', () {
      final p = generatePuzzle(99, PipeDifficulty.easy);
      final engine = PipeEngine(puzzle: p, label: 'test');
      final i = (p.pump + 1) % p.scrambled.length;
      final before = engine.tiles[i];
      engine.twist(i);
      expect(engine.moves, 1);
      expect(engine.tiles[i], rotateGlyph(before));
      engine.dispose();
    });

    test('rotateGlyph cycles correctly', () {
      expect(rotateGlyph('H'), 'V');
      expect(rotateGlyph('V'), 'H');
      expect(rotateGlyph(rotateGlyph('1')), '3');
      expect(rotateGlyph('a'), 'b');
      expect(rotateGlyph('d'), 'a');
      expect(rotateGlyph('+'), '+');
      expect(rotateGlyph('P'), 'P');
    });
  });

  group('settings', () {
    test('player names encode/decode as one JSON string', () {
      const names = ['Master Plumber'];
      final raw = PipeSettings.encodePlayerNames(names);
      expect(PipeSettings.decodePlayerNames(raw), names);
    });

    test('corrupt names fall back to default', () {
      expect(PipeSettings.decodePlayerNames('not-json'),
          [PipeSettings.defaultName]);
      expect(PipeSettings.decodePlayerNames(null),
          [PipeSettings.defaultName]);
    });

    test('daily streak date keys', () {
      final d = DateTime(2026, 10, 9);
      expect(PipeSettings.dateKey(d), '2026-10-09');
      expect(dailySeed(d), 20261009);
    });
  });
}
