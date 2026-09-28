import 'package:just_audio/just_audio.dart';

/// NovaAudio — a single, app-wide audio service for SocialNova.
///
/// Two responsibilities:
///  * [playMusic]/[stopMusic] — one background music track at a time, used by
///    Stories, Reels and Live so a chosen song actually plays with the media.
///  * [playSfx] — short, fire-and-forget sound effects (gift tiers, taps,
///    joins) played from bundled assets. Failures never throw: audio is a
///    nice-to-have and must never break a screen.
///
/// Every call is defensive: if the platform has no audio session (tests,
/// desktop CI), the call is a no-op instead of an exception.
class NovaAudio {
  NovaAudio._();
  static final NovaAudio i = NovaAudio._();

  // Bundled sound effects. Keys are what the gift catalog / live layer use.
  static const Map<String, String> sfxAssets = {
    'tap': 'assets/sfx/sfx_tap.wav',
    'common': 'assets/sfx/sfx_gift_common.wav',
    'luck': 'assets/sfx/sfx_gift_luck.wav',
    'luxury': 'assets/sfx/sfx_gift_luxury.wav',
    'exclusive': 'assets/sfx/sfx_gift_exclusive.wav',
    'combo': 'assets/sfx/sfx_combo.wav',
    'join': 'assets/sfx/sfx_join.wav',
    'go_live': 'assets/sfx/sfx_go_live.wav',
    'live_end': 'assets/sfx/sfx_live_end.wav',
  };

  AudioPlayer? _music;
  AudioPlayer? _active;
  bool _muted = false;
  String _currentUrl = '';

  final List<AudioPlayer> _sfxPool = [];
  int _sfxCursor = 0;
  static const int _sfxPoolSize = 4;

  bool get muted => _muted;
  bool get hasMusic => _active != null;
  String get currentMusic => _currentUrl;

  /// Plays [url] as background music. Passing the same url that is already
  /// playing keeps it going (no restart glitch). Silently ignores failures.
  Future<void> playMusic(String? url, {bool loop = true}) async {
    final clean = (url ?? '').trim();
    if (clean.isEmpty) return;
    if (clean == _currentUrl && _active != null && _active!.playing) return;
    try {
      final player = (_music != null && _music != _active) ? _music! : AudioPlayer();
      _music = player;
      _active = player;
      _currentUrl = clean;
      player.setLoopMode(loop ? LoopMode.one : LoopMode.off);
      player.setVolume(_muted ? 0 : 0.9);
      await player.setUrl(clean);
      if (_muted) await player.setVolume(0);
      unawaitedPlay(player);
    } catch (_) {
      _active = null;
    }
  }

  /// Play a bundled asset as background music (used for built-in tracks).
  Future<void> playAssetMusic(String assetPath, {bool loop = true}) async {
    if (assetPath == _currentUrl && _active != null && _active!.playing) return;
    try {
      final player = AudioPlayer();
      _music = player;
      _active = player;
      _currentUrl = assetPath;
      player.setLoopMode(loop ? LoopMode.one : LoopMode.off);
      player.setVolume(_muted ? 0 : 0.9);
      await player.setAsset(assetPath);
      unawaitedPlay(player);
    } catch (_) {
      _active = null;
    }
  }

  Future<void> stopMusic() async {
    _currentUrl = '';
    final active = _active;
    _active = null;
    if (active != null) {
      try {
        await active.stop();
        await active.dispose();
      } catch (_) {}
    }
    if (_music != null && _music != active) {
      try {
        await _music!.dispose();
      } catch (_) {}
    }
    _music = null;
  }

  Future<void> setMuted(bool value) async {
    _muted = value;
    for (final p in [_active, _music]) {
      try {
        await p?.setVolume(value ? 0 : 0.9);
      } catch (_) {}
    }
  }

  Future<void> toggleMute() => setMuted(!_muted);

  /// Plays a short effect. [key] is one of [sfxAssets]; unknown keys are
  /// ignored. Never throws, never awaits inside the caller's critical path.
  void playSfx(String key) {
    final path = sfxAssets[key];
    if (path == null || _muted) return;
    try {
      while (_sfxPool.length < _sfxPoolSize) {
        _sfxPool.add(AudioPlayer());
      }
      final player = _sfxPool[_sfxCursor % _sfxPoolSize];
      _sfxCursor++;
      player.setAsset(path).then((_) => unawaitedPlay(player)).catchError((_) {});
    } catch (_) {}
  }

  /// Gift sound helper so screens do not need to know the tier keys.
  void playGiftSfx(String tier) {
    switch (tier.toLowerCase()) {
      case 'exclusive':
      case 'حصرية':
        playSfx('exclusive');
        break;
      case 'luxury':
      case 'فاخرة':
        playSfx('luxury');
        break;
      case 'luck':
      case 'حظ':
        playSfx('luck');
        break;
      default:
        playSfx('common');
    }
  }

  void dispose() {
    for (final p in _sfxPool) {
      try {
        p.dispose();
      } catch (_) {}
    }
    _sfxPool.clear();
    stopMusic();
  }
}

/// Small indirection so a failed [play] never surfaces as an unhandled error.
void unawaitedPlay(AudioPlayer player) {
  player.play().catchError((_) {});
}
