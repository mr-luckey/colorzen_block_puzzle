import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:colorzen_block_puzzle/core/constants/admob_constants.dart';
import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:colorzen_block_puzzle/services/ad_unit_memory.dart';
import 'package:colorzen_block_puzzle/services/ads_remote_config.dart';
import 'package:colorzen_block_puzzle/services/network_status.dart';

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
/// Offline-safe: never touch MobileAds without internet; every load has a timeout
/// so splash / UI cannot hang waiting on AdMob Completers.
class AdMobService with WidgetsBindingObserver implements AdService {
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;

  DateTime? _lastInterstitialShown;
  DateTime? _lastFullscreenClosedAt;

  bool _initialized = false;
  bool _initializing = false;
  DateTime? _offlineUntil;

  Timer? _menuTimer;
  bool _menuAdsActive = false;
  bool _adsRemoved = false;
  bool _inGameplay = false;
  bool _lifecycleObserverAttached = false;

  /// Session show attempts (includes skip-first no-ops).
  int _interstitialAttempts = 0;

  _FsKind _active = _FsKind.none;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;

  /// After any fullscreen dismiss/cancel/fail — no new fullscreen for this window.
  static const _afterCloseCooldown = Duration(seconds: 5);
  static const _sdkInitTimeout = Duration(seconds: 5);
  static const _adLoadTimeout = Duration(seconds: 8);

  bool get _fullscreenBusy => _active != _FsKind.none;

  bool get _inAfterCloseCooldown {
    final t = _lastFullscreenClosedAt;
    if (t == null) return false;
    return DateTime.now().difference(t) < _afterCloseCooldown;
  }

  bool get _isOfflinePaused =>
      _offlineUntil != null && DateTime.now().isBefore(_offlineUntil!);

  void _enterOfflineMode({Duration forDuration = const Duration(seconds: 60)}) {
    markNetworkOffline();
    _offlineUntil = DateTime.now().add(forDuration);
  }

  Future<bool> _guardOnline({bool forceCheck = false}) async {
    if (_isOfflinePaused && !forceCheck) return false;
    final online = await hasInternetConnection(force: forceCheck);
    if (!online) {
      _enterOfflineMode();
      return false;
    }
    markNetworkOnline();
    _offlineUntil = null;
    return true;
  }

  bool _isNetworkAdError(LoadAdError error) {
    if (error.code == 0 || error.code == 2) return true;
    final msg = error.message.toLowerCase();
    return msg.contains('network') ||
        msg.contains('internal error') ||
        msg.contains('unable to resolve') ||
        msg.contains('unknown host');
  }

  void _ensureLifecycleObserver() {
    if (_lifecycleObserverAttached) return;
    WidgetsBinding.instance.addObserver(this);
    _lifecycleObserverAttached = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // ignore: discarded_futures
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    await AdsRemoteConfig.instance.refreshIfNeeded();
    _applyRemoteConfigGates();
  }

  void _applyRemoteConfigGates() {
    if (!AdsRemoteConfig.instance.interstitialAdsEnabled) {
      _clearInterstitial();
      _syncMenuTimer();
    }
  }

  void _clearInterstitial() {
    _interstitial?.dispose();
    _interstitial = null;
  }

  @override
  Future<void> init() async {
    _ensureLifecycleObserver();
    if (_initialized || _initializing) return;
    _initializing = true;
    try {
      // Never call MobileAds offline — hangs / ANR on splash otherwise.
      if (!await _guardOnline(forceCheck: true)) return;

      await MobileAds.instance.initialize().timeout(_sdkInitTimeout);
      _initialized = true;

      // Prefetch in background — never block startup on waterfall.
      // ignore: discarded_futures
      loadInterstitial();
      // ignore: discarded_futures
      loadRewarded();
    } catch (_) {
      _initialized = false;
      _enterOfflineMode(forDuration: const Duration(seconds: 90));
    } finally {
      _initializing = false;
    }
  }

  Future<bool> _ensureSdk() async {
    if (_initialized) return true;
    await init();
    return _initialized;
  }

  void _markClosed() {
    _active = _FsKind.none;
    _lastFullscreenClosedAt = DateTime.now();
  }

  // ─── Waterfall load (preferred ID first; stop on first success) ───

  Future<InterstitialAd?> _fetchInterstitial() async {
    if (!AdsRemoteConfig.instance.interstitialAdsEnabled) return null;
    if (_loadingInterstitial) return _interstitial;
    if (_interstitial != null) return _interstitial;
    if (!await _guardOnline()) return null;
    if (!await _ensureSdk()) return null;

    _loadingInterstitial = true;
    try {
      final ids = AdUnitMemory.interstitialOrder(AdMobConstants.interstitialIds);
      for (final id in ids) {
        if (_interstitial != null) return _interstitial;
        if (_isOfflinePaused) return null;
        if (!AdsRemoteConfig.instance.interstitialAdsEnabled) return null;

        final completer = Completer<InterstitialAd?>();
        try {
          await InterstitialAd.load(
            adUnitId: id,
            request: const AdRequest(),
            adLoadCallback: InterstitialAdLoadCallback(
              onAdLoaded: (ad) {
                if (!completer.isCompleted) completer.complete(ad);
              },
              onAdFailedToLoad: (error) {
                if (_isNetworkAdError(error)) {
                  _enterOfflineMode();
                }
                if (!completer.isCompleted) completer.complete(null);
              },
            ),
          );
        } catch (_) {
          if (!completer.isCompleted) completer.complete(null);
        }

        InterstitialAd? ad;
        try {
          ad = await completer.future.timeout(
            _adLoadTimeout,
            onTimeout: () => null,
          );
        } catch (_) {
          ad = null;
        }

        if (ad != null) {
          if (!AdsRemoteConfig.instance.interstitialAdsEnabled) {
            ad.dispose();
            return null;
          }
          _interstitial = ad;
          // ignore: discarded_futures
          AdUnitMemory.rememberInterstitial(id);
          return ad;
        }
        if (_isOfflinePaused) return null;
      }
      return null;
    } finally {
      _loadingInterstitial = false;
    }
  }

  Future<RewardedAd?> _fetchRewarded() async {
    if (_loadingRewarded) return _rewarded;
    if (_rewarded != null) return _rewarded;
    if (!await _guardOnline()) return null;
    if (!await _ensureSdk()) return null;

    _loadingRewarded = true;
    try {
      final ids = AdUnitMemory.rewardedOrder(AdMobConstants.rewardedIds);
      for (final id in ids) {
        if (_rewarded != null) return _rewarded;
        if (_isOfflinePaused) return null;

        final completer = Completer<RewardedAd?>();
        try {
          await RewardedAd.load(
            adUnitId: id,
            request: const AdRequest(),
            rewardedAdLoadCallback: RewardedAdLoadCallback(
              onAdLoaded: (ad) {
                if (!completer.isCompleted) completer.complete(ad);
              },
              onAdFailedToLoad: (error) {
                if (_isNetworkAdError(error)) {
                  _enterOfflineMode();
                }
                if (!completer.isCompleted) completer.complete(null);
              },
            ),
          );
        } catch (_) {
          if (!completer.isCompleted) completer.complete(null);
        }

        RewardedAd? ad;
        try {
          ad = await completer.future.timeout(
            _adLoadTimeout,
            onTimeout: () => null,
          );
        } catch (_) {
          ad = null;
        }

        if (ad != null) {
          _rewarded = ad;
          // ignore: discarded_futures
          AdUnitMemory.rememberRewarded(id);
          return ad;
        }
        if (_isOfflinePaused) return null;
      }
      return null;
    } finally {
      _loadingRewarded = false;
    }
  }

  @override
  Future<void> loadInterstitial() async {
    if (!AdsRemoteConfig.instance.interstitialAdsEnabled) {
      _clearInterstitial();
      return;
    }
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
    if (adsRemoved ||
        !AdsRemoteConfig.instance.interstitialAdsEnabled ||
        _fullscreenBusy ||
        _inAfterCloseCooldown) {
      return false;
    }
    if (!await _guardOnline()) return false;

    final last = _lastInterstitialShown;
    final minInterval = AdsRemoteConfig.instance.interstitialMinInterval;
    if (!ignoreCooldown &&
        last != null &&
        DateTime.now().difference(last) < minInterval) {
      return false;
    }

    // Skip-first (RC): consume one attempt without showing. Default false.
    _interstitialAttempts++;
    if (AdsRemoteConfig.instance.interstitialSkipFirst &&
        _interstitialAttempts == 1) {
      return false;
    }

    // Claim gate BEFORE awaits — blocks parallel interstitial/rewarded.
    _active = _FsKind.interstitial;

    try {
      final ad = _interstitial ?? await _fetchInterstitial();

      if (ad == null ||
          _active != _FsKind.interstitial ||
          !AdsRemoteConfig.instance.interstitialAdsEnabled) {
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
    // Rewarded is intentionally not gated by Remote Config.
    if (_fullscreenBusy || _inAfterCloseCooldown) return false;
    if (!await _guardOnline()) return false;

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
    final shouldRun = _menuAdsActive &&
        !_adsRemoved &&
        !_inGameplay &&
        AdsRemoteConfig.instance.interstitialAdsEnabled;
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
        !AdsRemoteConfig.instance.interstitialAdsEnabled ||
        _fullscreenBusy ||
        _inAfterCloseCooldown) {
      return;
    }
    // Same gated path as game interstitials — cannot overlap rewarded.
    await showInterstitial(adsRemoved: _adsRemoved, ignoreCooldown: true);
  }
}
