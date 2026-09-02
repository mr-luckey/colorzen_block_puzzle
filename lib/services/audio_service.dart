import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import 'package:colorzen_block_puzzle/domain/models/models.dart';

enum SfxType {
  tap,
  pickup,
  place,
  clear,
  lineClear,
  blast,
  combo,
  invalid,
  gameOver,
  tick,
}

abstract class AudioService {
  Future<void> init();
  Future<void> playSfx(SfxType type);
  Future<void> playMusic();
  Future<void> pauseMusic();
  Future<void> stopMusic();
  Future<void> setMusicVolume(double volume);
  Future<void> syncFromSettings(AppSettings settings);

  /// Pause BGM + SFX when app goes to background.
  Future<void> onAppPaused();

  /// Resume BGM when app returns to foreground.
  Future<void> onAppResumed();

  /// Call after first frame / tap / resume so Android allows playback.
  Future<void> ensureMusicPlaying();
}

class AudioPlayersService implements AudioService {
  AudioPlayersService({required this.settingsProvider});

  final AppSettings Function() settingsProvider;

  final AudioPlayer _music = AudioPlayer();
  AudioPlayer? _tick;
  bool _ready = false;
  bool _starting = false;
  bool _wantMusic = false;
  bool _appInForeground = true;
  bool _intentionallyPaused = false;

  static const _bgm = 'audio/bgm_colorzen.ogg';
  static const _tickAsset = 'audio/tick.wav';

  /// Keep BGM softer than the slider so it stays chill behind SFX.
  static const _musicSoftFactor = 0.55;

  /// Mix BGM + SFX; never steal exclusive focus (that kills the loop on Android).
  static final AudioContext _mixCtx = AudioContextConfig(
    route: AudioContextConfigRoute.system,
    focus: AudioContextConfigFocus.mixWithOthers,
  ).build();

  double get _musicGain =>
      (settingsProvider().musicVolume.clamp(0.0, 1.0) * _musicSoftFactor)
          .clamp(0.0, 1.0);

  bool get _musicAllowed =>
      _ready &&
      _appInForeground &&
      settingsProvider().musicEnabled &&
      _wantMusic;

  @override
  Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(_mixCtx);

      await _music.setAudioContext(_mixCtx);
      await _music.setPlayerMode(PlayerMode.mediaPlayer);
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(_musicGain);

      _music.onPlayerComplete.listen((_) {
        if (!_musicAllowed) return;
        // ignore: discarded_futures
        Future<void>.delayed(const Duration(milliseconds: 40), playMusic);
      });

      // If Android pauses/stops BGM (focus / ad / route change), bring it back.
      _music.onPlayerStateChanged.listen((state) {
        if (state == PlayerState.playing) return;
        if (!_musicAllowed || _intentionallyPaused || _starting) return;
        // ignore: discarded_futures
        Future<void>.delayed(const Duration(milliseconds: 120), () {
          if (!_musicAllowed ||
              _intentionallyPaused ||
              _music.state == PlayerState.playing) {
            return;
          }
          // ignore: discarded_futures
          playMusic();
        });
      });

      _ready = true;

      try {
        final tick = AudioPlayer();
        await tick.setAudioContext(_mixCtx);
        try {
          await tick.setPlayerMode(PlayerMode.lowLatency);
        } catch (_) {
          await tick.setPlayerMode(PlayerMode.mediaPlayer);
        }
        await tick.setReleaseMode(ReleaseMode.stop);
        await tick.setVolume(0.94);
        _tick = tick;
      } catch (_) {
        _tick = null;
      }
    } catch (_) {
      _ready = false;
    }
  }

  @override
  Future<void> playSfx(SfxType type) async {
    // One reused player — extra MediaPlayers ANR this OEM.
    if (type != SfxType.tick) return;
    if (!_ready || !_appInForeground) return;
    if (!settingsProvider().sfxEnabled) return;
    final player = _tick;
    if (player == null) return;
    try {
      await player.stop();
      await player.play(AssetSource(_tickAsset), volume: 0.94);
    } catch (_) {}
  }

  @override
  Future<void> playMusic() async {
    if (!_ready || !_appInForeground || !settingsProvider().musicEnabled) {
      return;
    }
    _wantMusic = true;
    _intentionallyPaused = false;
    if (_starting) return;
    if (_music.state == PlayerState.playing) {
      await _music.setVolume(_musicGain);
      return;
    }
    _starting = true;
    try {
      await _music.setAudioContext(_mixCtx);
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(_musicGain);
      if (_music.state == PlayerState.paused) {
        await _music.resume();
        // Some devices report paused but resume is a no-op after focus loss.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (_music.state == PlayerState.playing) return;
      }
      await _music.stop();
      await _music.play(AssetSource(_bgm), volume: _musicGain);
    } catch (_) {
      try {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (!_appInForeground || !settingsProvider().musicEnabled) return;
        await _music.setReleaseMode(ReleaseMode.loop);
        await _music.play(AssetSource(_bgm), volume: _musicGain);
      } catch (_) {}
    } finally {
      _starting = false;
    }
  }

  @override
  Future<void> pauseMusic() async {
    _intentionallyPaused = true;
    try {
      if (_music.state == PlayerState.playing ||
          _music.state == PlayerState.paused) {
        await _music.pause();
      }
    } catch (_) {}
  }

  @override
  Future<void> ensureMusicPlaying() async {
    if (!_ready || !_appInForeground || !settingsProvider().musicEnabled) {
      return;
    }
    _wantMusic = true;
    _intentionallyPaused = false;
    if (_music.state == PlayerState.playing) return;
    await playMusic();
  }

  @override
  Future<void> stopMusic() async {
    _wantMusic = false;
    _intentionallyPaused = true;
    try {
      await _music.stop();
    } catch (_) {}
  }

  @override
  Future<void> onAppPaused() async {
    _appInForeground = false;
    await pauseMusic();
  }

  @override
  Future<void> onAppResumed() async {
    _appInForeground = true;
    if (!settingsProvider().musicEnabled) return;
    _wantMusic = true;
    _intentionallyPaused = false;
    // Ads / system UI often need a beat before media can restart.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await ensureMusicPlaying();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (_musicAllowed && _music.state != PlayerState.playing) {
      await playMusic();
    }
  }

  @override
  Future<void> setMusicVolume(double volume) async {
    try {
      final gain =
          (volume.clamp(0.0, 1.0) * _musicSoftFactor).clamp(0.0, 1.0);
      await _music.setVolume(gain);
    } catch (_) {}
  }

  @override
  Future<void> syncFromSettings(AppSettings settings) async {
    await setMusicVolume(settings.musicVolume);
    if (settings.musicEnabled && _appInForeground) {
      _wantMusic = true;
      await playMusic();
    } else {
      await stopMusic();
    }
  }
}

/// Starts / resumes BGM after UI is up; pauses all audio in background.
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
    switch (state) {
      case AppLifecycleState.resumed:
        // ignore: discarded_futures
        MusicBootstrapHooks.onResumed?.call();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // ignore: discarded_futures
        MusicBootstrapHooks.onPaused?.call();
      case AppLifecycleState.inactive:
        // Transient (system UI / gesture) — keep music until paused/hidden.
        break;
    }
  }

  Future<void> _kick() async {
    try {
      await MusicBootstrapHooks.ensureMusic?.call();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Wired from DI so MusicBootstrap doesn't import GetIt circularly.
class MusicBootstrapHooks {
  static Future<void> Function()? ensureMusic;
  static Future<void> Function()? onPaused;
  static Future<void> Function()? onResumed;
}
