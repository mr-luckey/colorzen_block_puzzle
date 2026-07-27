import 'dart:async';

import 'package:colorzen_block_puzzle/core/constants/admob_constants.dart';
import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:colorzen_block_puzzle/services/ad_unit_memory.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

abstract class AdService {
  Future<void> init();
  Future<void> loadInterstitial();
  Future<bool> showInterstitial({
    required bool adsRemoved,
    bool ignoreCooldown = false,
  });
  Future<void> loadRewarded();
  Future<bool> showRewarded({required void Function() onEarned});

  /// Menu-only loop: interstitial every 20s while user is outside gameplay.
  void setMenuAdsActive({required bool active, required bool adsRemoved});

  /// Hard lock: while true, menu interstitial never shows (even if Home rebuilds).
  void setInGameplay(bool inGameplay);
}

enum _FsKind { none, interstitial, rewarded }

/// 5-ID waterfall per type, remembers last working unit, one fullscreen at a time.
///
/// Rules:
/// - Try unit IDs one-by-one until one loads, then stop (never parallel load).
/// - Never present 2 interstitials or 2 rewardeds (or mixed) together.
/// - After user closes/cancels a fullscreen ad, block the next one briefly
///   so cancel ≠ instant next ad.
class AdMobService implements AdService {
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;

  DateTime? _lastInterstitialShown;
  DateTime? _lastFullscreenClosedAt;

  bool _initialized = false;

  Timer? _menuTimer;
  bool _menuAdsActive = false;
  bool _adsRemoved = false;
  bool _inGameplay = false;

  _FsKind _active = _FsKind.none;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;

  /// After any fullscreen dismiss/cancel/fail — no new fullscreen for this window.
  static const _afterCloseCooldown = Duration(seconds: 5);

  bool get _fullscreenBusy => _active != _FsKind.none;

  bool get _inAfterCloseCooldown {
    final t = _lastFullscreenClosedAt;
    if (t == null) return false;
    return DateTime.now().difference(t) < _afterCloseCooldown;
  }

  @override
  Future<void> init() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      await loadInterstitial();
      await loadRewarded();
    } catch (_) {
      _initialized = false;
    }
  }

  void _markClosed() {
    _active = _FsKind.none;
    _lastFullscreenClosedAt = DateTime.now();
  }

  // ─── Waterfall load (preferred ID first; stop on first success) ───

  Future<InterstitialAd?> _fetchInterstitial() async {
    if (_loadingInterstitial) return _interstitial;
    if (_interstitial != null) return _interstitial;
    _loadingInterstitial = true;
    try {
      final ids = AdUnitMemory.interstitialOrder(AdMobConstants.interstitialIds);
      for (final id in ids) {
        if (_interstitial != null) return _interstitial;
        final completer = Completer<InterstitialAd?>();
        try {
          await InterstitialAd.load(
            adUnitId: id,
            request: const AdRequest(),
            adLoadCallback: InterstitialAdLoadCallback(
              onAdLoaded: (ad) {
                if (!completer.isCompleted) completer.complete(ad);
              },
              onAdFailedToLoad: (_) {
                if (!completer.isCompleted) completer.complete(null);
              },
            ),
          );
        } catch (_) {
          if (!completer.isCompleted) completer.complete(null);
        }
        final ad = await completer.future;
        if (ad != null) {
          _interstitial = ad;
          // ignore: discarded_futures
          AdUnitMemory.rememberInterstitial(id);
          return ad;
        }
      }
      return null;
    } finally {
      _loadingInterstitial = false;
    }
  }

  Future<RewardedAd?> _fetchRewarded() async {
    if (_loadingRewarded) return _rewarded;
    if (_rewarded != null) return _rewarded;
    _loadingRewarded = true;
    try {
      final ids = AdUnitMemory.rewardedOrder(AdMobConstants.rewardedIds);
      for (final id in ids) {
        if (_rewarded != null) return _rewarded;
        final completer = Completer<RewardedAd?>();
        try {
          await RewardedAd.load(
            adUnitId: id,
            request: const AdRequest(),
            rewardedAdLoadCallback: RewardedAdLoadCallback(
              onAdLoaded: (ad) {
                if (!completer.isCompleted) completer.complete(ad);
              },
              onAdFailedToLoad: (_) {
                if (!completer.isCompleted) completer.complete(null);
              },
            ),
          );
        } catch (_) {
          if (!completer.isCompleted) completer.complete(null);
        }
        final ad = await completer.future;
        if (ad != null) {
          _rewarded = ad;
          // ignore: discarded_futures
          AdUnitMemory.rememberRewarded(id);
          return ad;
        }
      }
      return null;
    } finally {
      _loadingRewarded = false;
    }
  }

  @override
  Future<void> loadInterstitial() async {
    await _fetchInterstitial();
  }

  @override
  Future<void> loadRewarded() async {
    await _fetchRewarded();
  }

  // ─── Show (single gate) ───

  @override
  Future<bool> showInterstitial({
    required bool adsRemoved,
    bool ignoreCooldown = false,
  }) async {
    if (adsRemoved || _fullscreenBusy || _inAfterCloseCooldown) {
      return false;
    }

    final last = _lastInterstitialShown;
    if (!ignoreCooldown &&
        last != null &&
        DateTime.now().difference(last).inMilliseconds <
            AppConstants.interstitialCooldownMs) {
      return false;
    }

    // Claim gate BEFORE awaits — blocks parallel interstitial/rewarded.
    _active = _FsKind.interstitial;

    try {
      final ad = _interstitial ?? await _fetchInterstitial();

      if (ad == null || _active != _FsKind.interstitial) {
        if (_active == _FsKind.interstitial) _active = _FsKind.none;
        return false;
      }

      // Detach cached instance so nothing else can show the same ad.
      _interstitial = null;
      _lastInterstitialShown = DateTime.now();

      final done = Completer<bool>();
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (shown) {
          shown.dispose();
          _markClosed();
          // Prefetch only — never auto-show after dismiss/cancel.
          loadInterstitial();
          if (!done.isCompleted) done.complete(true);
        },
        onAdFailedToShowFullScreenContent: (shown, _) {
          shown.dispose();
          _markClosed();
          loadInterstitial();
          if (!done.isCompleted) done.complete(false);
        },
      );

      try {
        await ad.show();
      } catch (_) {
        ad.dispose();
        _markClosed();
        loadInterstitial();
        if (!done.isCompleted) done.complete(false);
        return false;
      }
      return done.future;
    } catch (_) {
      if (_active == _FsKind.interstitial) _markClosed();
      loadInterstitial();
      return false;
    }
  }

  @override
  Future<bool> showRewarded({required void Function() onEarned}) async {
    // Never stack with interstitial / another rewarded; never right after cancel.
    if (_fullscreenBusy || _inAfterCloseCooldown) return false;

    _active = _FsKind.rewarded;

    try {
      final ad = _rewarded ?? await _fetchRewarded();

      if (ad == null || _active != _FsKind.rewarded) {
        if (_active == _FsKind.rewarded) _active = _FsKind.none;
        return false;
      }

      _rewarded = null;
      var earned = false;
      final done = Completer<bool>();

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (shown) {
          shown.dispose();
          _markClosed();
          // Load next in background — do NOT present it.
          loadRewarded();
          if (!done.isCompleted) done.complete(earned);
        },
        onAdFailedToShowFullScreenContent: (shown, _) {
          shown.dispose();
          _markClosed();
          loadRewarded();
          if (!done.isCompleted) done.complete(false);
        },
      );

      try {
        await ad.show(
          onUserEarnedReward: (_, _) {
            earned = true;
            onEarned();
          },
        );
      } catch (_) {
        ad.dispose();
        _markClosed();
        loadRewarded();
        if (!done.isCompleted) done.complete(false);
        return false;
      }
      return done.future;
    } catch (_) {
      if (_active == _FsKind.rewarded) _markClosed();
      loadRewarded();
      return false;
    }
  }

  // ─── Menu interstitial loop ───

  @override
  void setMenuAdsActive({required bool active, required bool adsRemoved}) {
    _adsRemoved = adsRemoved;
    _menuAdsActive = active && !adsRemoved;
    _syncMenuTimer();
  }

  @override
  void setInGameplay(bool inGameplay) {
    _inGameplay = inGameplay;
    if (inGameplay) {
      _menuTimer?.cancel();
      _menuTimer = null;
      return;
    }
    _syncMenuTimer();
  }

  void _syncMenuTimer() {
    final shouldRun = _menuAdsActive && !_adsRemoved && !_inGameplay;
    if (!shouldRun) {
      _menuTimer?.cancel();
      _menuTimer = null;
      return;
    }
    if (_menuTimer != null) return;
    _menuTimer = Timer.periodic(
      const Duration(seconds: AppConstants.menuInterstitialEverySec),
      (_) => _tickMenuInterstitial(),
    );
  }

  Future<void> _tickMenuInterstitial() async {
    if (!_menuAdsActive ||
        _adsRemoved ||
        _inGameplay ||
        _fullscreenBusy ||
        _inAfterCloseCooldown) {
      return;
    }
    // Same gated path as game interstitials — cannot overlap rewarded.
    await showInterstitial(adsRemoved: _adsRemoved, ignoreCooldown: true);
  }
}
