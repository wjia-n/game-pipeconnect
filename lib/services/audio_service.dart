import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural audio for Pipe Connect — all sounds synthesized in code as WAV
/// bytes. No asset files. Physical, workshop-appropriate sounds: metal
/// ratchets, water gurgles, valve pops.
///
/// Reliability design (every call is safe to repeat and safe to overlap):
/// - Music clips are synthesized ONCE and cached; starting music never blocks
///   the UI thread after the first build.
/// - A [_musicGen] generation counter serializes track changes: every
///   start/stop bumps the generation, in-flight work from an older request
///   aborts, and the LATEST request always wins. Music is app-scoped and
///   never silently dies.
/// - Lifecycle uses pause()/resume() so an interruption (call, backgrounding)
///   resumes exactly where it left off instead of restarting or dying.
/// - Every public method catches player errors; audio can never crash the app.
class PipeAudio {
  /// Per-game pitch character (pipeconnect): 1.35x. Makes SFX unique.
  static const double _pitchMul = 1.350;

  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  final Map<String, Uint8List> _cache = {};

  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  PipeAudio() {
    _music.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    volume = volume.clamp(0.0, 1.0);
    this.volume = volume;
    _music.setVolume(musicOn ? volume * 0.5 : 0.0);
    _sfx.setVolume(sfxOn ? volume : 0.0);
    if (!musicOn) {
      stopMusic();
    }
  }

  /// Pre-build music clips off the critical path. Safe to call any time.
  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, 2.2).toDouble();
    return a * d;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0, double attack = 0.02, double harmonics = 0.25}) {
    freq *= _pitchMul;
    freqEnd *= _pitchMul;
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  List<double> _ratchet() {
    // Wrench ratchet: metallic click train.
    final n = (_rate * 0.12).round();
    final out = List<double>.filled(n, 0);
    for (int click = 0; click < 3; click++) {
      final start = (n * click / 3.4).round();
      final len = (_rate * 0.03).round();
      for (int i = 0; i < len && start + i < n; i++) {
        final t = i / _rate;
        out[start + i] += (_rand.nextDouble() * 2 - 1) *
            exp(-t * 160) *
            (0.6 + 0.4 * sin(2 * pi * 2400 * t));
      }
    }
    return out;
  }

  List<double> _gurgle() {
    // Water gurgle: filtered noise with a rising bubble sweep.
    final n = (_rate * 0.5).round();
    final out = List<double>.filled(n, 0);
    double lp = 0;
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final noise = _rand.nextDouble() * 2 - 1;
      lp += 0.08 * (noise - lp);
      final bubble = sin(2 * pi * (120 + 500 * t / 0.5) * t);
      out[i] = _env(i, n, attack: 0.15) * (lp * 0.8 + bubble * 0.25 * lp);
    }
    return out;
  }

  List<double> _valvePop() {
    // Valve pop: pressure click + air release.
    final n = (_rate * 0.22).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.01) *
          (sin(2 * pi * 300 * t) * exp(-t * 25) +
              0.4 * (_rand.nextDouble() * 2 - 1) * exp(-t * 60));
    }
    return out;
  }

  List<double> _bubble() {
    // Hint bubble: soft rising blip.
    return _tone(500, 0.25, freqEnd: 900, harmonics: 0.4);
  }

  List<double> _thud() {
    // Invalid: dull metal thud.
    final n = (_rate * 0.16).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.005) *
          (sin(2 * pi * 110 * t) * exp(-t * 28) +
              0.3 * sin(2 * pi * 220 * t) * exp(-t * 45));
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(_tone(f, noteSecs, harmonics: 0.2));
      out.addAll(List<double>.filled((_rate * gapSecs).round(), 0));
    }
    return out;
  }

  List<double> _padChord(List<double> freqs, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      double v = 0;
      for (final f in freqs) {
        final t = i / _rate;
        v += sin(2 * pi * f * t) + 0.3 * sin(2 * pi * f * 2 * t);
      }
      v /= freqs.length * 1.3;
      final t = i / n;
      final swell = sin(pi * t.clamp(0.0, 1.0));
      out[i] = v * (0.35 + 0.65 * swell);
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  Uint8List _menuBytes() => _clip('music_menu', () {
        // C# waltz 5 – 3 – 0 – 4, 12s loop. Unique to pipeconnect.
        final seq = [
          [233.08, 277.18, 349.22],
          [185.00, 233.08, 277.18],
          [138.59, 174.61, 207.65],
          [207.65, 261.62, 311.12]
        ];
        final out = <double>[];
        for (final chord in seq) {
          // Waltz: bass on 1, chords on 2 and 3
          final bass = _tone(chord[0] / 2, 0.8, harmonics: 0.3);
          final ch1 = _padChord([chord[1], chord[2]], 0.7);
          final ch2 = _padChord([chord[1], chord[2]], 0.7);
          out.addAll(bass);
          final gap1 = List<double>.filled((_rate * 0.2).round(), 0);
          out.addAll(gap1);
          out.addAll(ch1);
          final gap2 = List<double>.filled((_rate * 0.2).round(), 0);
          out.addAll(gap2);
          out.addAll(ch2);
          final gap3 = List<double>.filled((_rate * 0.2).round(), 0);
          out.addAll(gap3);
        }
        return out;
      });


  Uint8List _gameBytes() => _clip('music_game', () {
        // C# arpeggiated 5 – 3 – 0 – 4, 16s loop. Unique to pipeconnect.
        final notes = [233.08, 277.18, 349.22, 277.18, 185.00, 233.08, 277.18, 233.08, 138.59, 174.61, 207.65, 174.61, 207.65, 261.62, 311.12, 261.62];
        final out = <double>[];
        final noteLen = 16.0 / notes.length;
        for (final n in notes) {
          out.addAll(_tone(n, noteLen * 0.9, harmonics: 0.3));
          final gap = List<double>.filled((_rate * noteLen * 0.1).round(), 0);
          out.addAll(gap);
        }
        // Soft pad underneath
        final pad = _padChord([233.08, 277.18, 349.22], 16.0);
        for (int i = 0; i < out.length && i < pad.length; i++) {
          out[i] += pad[i] * 0.3;
        }
        return out;
      });


  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() => _play(_clip('click', () => _tone(1150, 0.06)));
  Future<void> twist() => _play(_clip('twist', _ratchet));
  Future<void> flow() => _play(_clip('flow', _gurgle));
  Future<void> connect() => _play(_clip('connect', _valvePop));
  Future<void> hint() => _play(_clip('hint', _bubble));
  Future<void> invalid() => _play(_clip('invalid', _thud));
  Future<void> gameStart() =>
      _play(_clip('start', () => _tone(300, 0.35, freqEnd: 620)));
  Future<void> win() => _play(_clip('win',
      () => _arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.16, 0.03)));
  Future<void> lose() =>
      _play(_clip('lose', () => _tone(400, 0.5, freqEnd: 120)));

  // ----------------------------------------------------------------- music
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !musicOn) return;
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  Future<void> stopMusic() async {
    ++_musicGen;
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
    } catch (_) {}
  }
}
