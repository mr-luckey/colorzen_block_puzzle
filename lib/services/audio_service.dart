import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import 'package:colorzen_block_puzzle/domain/models/models.dart';

enum SfxType { tap, pickup, place, clear, combo, invalid, gameOver, tick }

abstract class AudioService {
  Future<void> init();
  Future<void> playSfx(SfxType type);
  Future<void> playMusic();
  Future<void> stopMusic();
  Future<void> setMusicVolume(double volume);
  Future<void> syncFromSettings(AppSettings settings);

  /// Call after first frame / tap / resume so Android allows playback.
  Future<void> ensureMusicPlaying();
}

class AudioPlayersService implements AudioService {
  AudioPlayersService({required this.settingsProvider});

  final AppSettings Function() settingsProvider;

  final List<AudioPlayer> _sfxPool = [];
  final AudioPlayer _music = AudioPlayer();
  int _sfxIndex = 0;
  bool _ready = false;
  bool _starting = false;
  bool _wantMusic = false;

  static const _bgm = 'audio/bgm_colorzen.wav';

  static const _files = {
    SfxType.tap: 'audio/tap.wav',
    SfxType.pickup: 'audio/pickup.wav',
    SfxType.place: 'audio/place.wav',
    SfxType.clear: 'audio/clear.wav',
    SfxType.combo: 'audio/combo.wav',
    SfxType.invalid: 'audio/invalid.wav',
    SfxType.gameOver: 'audio/clear.wav',
    SfxType.tick: 'audio/tick.wav',
  };

  double get _musicGain =>
      settingsProvider().musicVolume.clamp(0.0, 1.0);

  @override
  Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          route: AudioContextConfigRoute.system,
          focus: AudioContextConfigFocus.gain,
        ).build(),
      );

      for (var i = 0; i < 3; i++) {
        final p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        _sfxPool.add(p);
      }

      await _music.setPlayerMode(PlayerMode.mediaPlayer);
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(_musicGain);

      _music.onPlayerStateChanged.listen((state) {
        if (!_wantMusic || !_ready) return;
        if (!settingsProvider().musicEnabled) return;
        if (state == PlayerState.completed) {
          // ignore: discarded_futures
          Future<void>.delayed(const Duration(milliseconds: 80), playMusic);
        }
      });

      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  @override
  Future<void> playSfx(SfxType type) async {
    if (!_ready || !settingsProvider().sfxEnabled || _sfxPool.isEmpty) return;
    final file = _files[type];
    if (file == null) return;
    try {
      // First tap also unlocks BGM on Android.
      // ignore: discarded_futures
      ensureMusicPlaying();
      final player = _sfxPool[_sfxIndex % _sfxPool.length];
      _sfxIndex++;
      await player.stop();
      await player.play(
        AssetSource(file),
        volume: type == SfxType.tick ? 0.55 : 0.95,
      );
    } catch (_) {}
  }

  @override
  Future<void> playMusic() async {
    if (!_ready || !settingsProvider().musicEnabled) return;
    _wantMusic = true;
    if (_starting) return;
    if (_music.state == PlayerState.playing) {
      await _music.setVolume(_musicGain);
      return;
    }
    _starting = true;
    try {
      await _music.stop();
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(_musicGain);
      await _music.play(AssetSource(_bgm), volume: _musicGain);
    } catch (_) {
      // Retry once shortly (common right after cold start).
      try {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (!settingsProvider().musicEnabled) return;
        await _music.play(AssetSource(_bgm), volume: _musicGain);
      } catch (_) {}
    } finally {
      _starting = false;
    }
  }

  @override
  Future<void> ensureMusicPlaying() async {
    if (!_ready || !settingsProvider().musicEnabled) return;
    if (_music.state == PlayerState.playing) return;
    await playMusic();
  }

  @override
  Future<void> stopMusic() async {
    _wantMusic = false;
    try {
      await _music.stop();
    } catch (_) {}
  }

  @override
  Future<void> setMusicVolume(double volume) async {
    try {
      await _music.setVolume(volume.clamp(0.0, 1.0));
    } catch (_) {}
  }

  @override
  Future<void> syncFromSettings(AppSettings settings) async {
    await setMusicVolume(settings.musicVolume);
    if (settings.musicEnabled) {
      await playMusic();
    } else {
      await stopMusic();
    }
  }
}

/// Starts / resumes BGM after UI is up and when app returns to foreground.
class MusicBootstrap extends StatefulWidget {
  const MusicBootstrap({super.key, required this.child});

  final Widget child;

  @override
  State<MusicBootstrap> createState() => _MusicBootstrapState();
}

class _MusicBootstrapState extends State<MusicBootstrap>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _kick();
    });
    // Second kick after splash-ish delay (Android often needs a later start).
    Future<void>.delayed(const Duration(milliseconds: 900), _kick);
    Future<void>.delayed(const Duration(milliseconds: 2000), _kick);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _kick();
    }
  }

  Future<void> _kick() async {
    try {
      // Lazy import avoidance: resolve via GetIt at call site in main.
      await MusicBootstrapHooks.ensureMusic?.call();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Wired from DI so MusicBootstrap doesn't import GetIt circularly.
class MusicBootstrapHooks {
  static Future<void> Function()? ensureMusic;
}
