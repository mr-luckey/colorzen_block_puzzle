import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Live frame-time budget so FX stay buttery on low-end phones.
///
/// Starts from a screen-size guess, then follows an EMA of vsync dt.
/// Gameplay rules never change — only paint cost.
class PerfTier {
  PerfTier._();
  static final PerfTier instance = PerfTier._();

  double _emaMs = 16.6;
  int _samples = 0;
  Duration? _last;
  bool _hooked = false;
  bool? _screenGuessLow;

  void ensureHooked() {
    if (_hooked) return;
    _hooked = true;
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
  }

  void _onFrame(Duration timestamp) {
    final prev = _last;
    _last = timestamp;
    if (prev == null) return;
    final dt = (timestamp - prev).inMicroseconds / 1e6;
    if (dt <= 0 || dt > 0.08) return;
    final ms = dt * 1000;
    _emaMs = _samples < 10 ? ms : (_emaMs * 0.88 + ms * 0.12);
    _samples++;
  }

  bool _guessLowFromScreen() {
    final cached = _screenGuessLow;
    if (cached != null) return cached;
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      _screenGuessLow = false;
      return false;
    }
    final view = views.first;
    final px = view.physicalSize.width * view.physicalSize.height;
    // Below ~HD fill, or very high DPR on a small GPU.
    _screenGuessLow = px < 720 * 1280 ||
        (view.devicePixelRatio >= 3.0 && px < 1080 * 1920);
    return _screenGuessLow!;
  }

  /// True when frames are slipping or the panel is a weak GPU.
  bool get isLowEnd {
    if (_samples > 20) return _emaMs > 20.5;
    return _guessLowFromScreen();
  }

  bool get isVeryLow {
    if (_samples > 20) return _emaMs > 27;
    return _guessLowFromScreen();
  }

  /// Soft GPU blur (saveLayer). Skip on weak devices.
  bool get useBlur => !isLowEnd;

  /// Extra screen-center confetti on top of board FX.
  bool get screenBurst => !isVeryLow;

  int get shatterShards => isVeryLow ? 3 : (isLowEnd ? 4 : 6);

  int get sparkles => isVeryLow ? 2 : (isLowEnd ? 3 : 4);
}
