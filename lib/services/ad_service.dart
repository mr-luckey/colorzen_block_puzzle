import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:colorzen_block_puzzle/core/config/ads_config.dart';
import 'package:colorzen_block_puzzle/services/ads_remote_config.dart';
import 'package:colorzen_block_puzzle/services/network_guard.dart';

abstract class AdService {
  Future<void> init();
  Future<BannerAd?> loadBanner({
    required String placement,
    required AdSize size,
  });
  Future<void> preloadInterstitial({
    String placement = AdsPlacements.afterSession,
  });
  Future<bool> showInterstitial({
    required bool adsRemoved,
    String placement = AdsPlacements.afterSession,
  });
  Future<void> preloadRewarded({
    String placement = AdsPlacements.dailyChallenge,
  });
  Future<bool> showRewarded({
    required String placement,
    required void Function() onEarned,
  });
}

/// Placement-based AdMob. No waterfall. Offline = idle. Never throws to UI.
class AdsService with WidgetsBindingObserver implements AdService {
  AdsService({
    AdsConfig? config,
    NetworkGuard? network,
  })  : _config = config ?? colorZenAdsConfig(),
        _network = network ?? NetworkGuard();

  final AdsConfig _config;
  final NetworkGuard _network;

  bool _sdkInitialized = false;
  bool _initializing = false;
  bool _started = false;
  bool _lifecycleObserverAttached = false;
  bool _fullScreenShowing = false;
  DateTime? _lastFullScreenAt;

  InterstitialAd? _interstitial;
  String? _interstitialPlacement;
  RewardedAd? _rewarded;
  String? _rewardedPlacement;

  int _interstitialLoadAttempts = 0;
  int _rewardedLoadAttempts = 0;
  int _interstitialShowAttempts = 0;
  Timer? _interstitialRetry;
  Timer? _rewardedRetry;

  static const _afterCloseCooldown = Duration(seconds: 5);
  static const _sdkInitTimeout = Duration(seconds: 5);

  bool get isOnline => _network.isOnline;

  bool get _inAfterCloseCooldown {
    final t = _lastFullScreenAt;
    if (t == null) return false;
    return DateTime.now().difference(t) < _afterCloseCooldown;
  }

  @override
  Future<void> init() async {
    _ensureLifecycleObserver();
    if (_started) {
      if (_network.isOnline) await _ensureSdk();
      return;
    }
    _started = true;
    await _network.start(onOnline: _onNetworkRestored);
    if (_network.isOnline) {
      await _ensureSdk();
    }
  }

  void _ensureLifecycleObserver() {
    if (_lifecycleObserverAttached) return;
    WidgetsBinding.instance.addObserver(this);
    _lifecycleObserverAttached = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // ignore: discarded_futures
    AdsRemoteConfig.instance.refreshIfNeeded();
  }

  void _onNetworkRestored() {
    _interstitialLoadAttempts = 0;
    _rewardedLoadAttempts = 0;
    unawaited(_ensureSdk());
  }

  @override
  Future<BannerAd?> loadBanner({
    required String placement,
    required AdSize size,
  }) async {
    if (!AdsRemoteConfig.instance.bannerAdsEnabled) return null;
    final unitId = _config.bannerUnitId(placement);
    if (unitId == null) return null;
    if (!await _canUseAds()) return null;
    try {
      final completer = Completer<BannerAd?>();
      final ad = BannerAd(
        adUnitId: unitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (loaded) {
            if (!completer.isCompleted) completer.complete(loaded as BannerAd);
          },
          onAdFailedToLoad: (failed, error) {
            debugPrint('Banner no-fill/fail [$placement]: $error');
            failed.dispose();
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      );
      await ad.load();
      return completer.future.timeout(
        _config.requestTimeout,
        onTimeout: () {
          ad.dispose();
          return null;
        },
      );
    } catch (error, stack) {
      debugPrint('loadBanner failed: $error\n$stack');
      return null;
    }
  }

  @override
  Future<void> preloadInterstitial({
    String placement = AdsPlacements.afterSession,
  }) async {
    if (!AdsRemoteConfig.instance.interstitialAdsEnabled) {
      _clearInterstitial();
      return;
    }
    if (_interstitial != null && _interstitialPlacement == placement) return;
    final unitId = _config.interstitialUnitId(placement);
    if (unitId == null) return;
    if (!await _canUseAds()) return;
    if (_interstitialLoadAttempts > _config.maxRetries) return;

    try {
      _interstitialRetry?.cancel();
      _clearInterstitial();
      final completer = Completer<InterstitialAd?>();
      await InterstitialAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: completer.complete,
          onAdFailedToLoad: (error) {
            debugPrint('Interstitial no-fill/fail [$placement]: $error');
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      );
      final ad = await completer.future.timeout(
        _config.requestTimeout,
        onTimeout: () => null,
      );
      if (ad == null) {
        _interstitialLoadAttempts++;
        _scheduleInterstitialRetry(placement);
        return;
      }
      _interstitialLoadAttempts = 0;
      _interstitialPlacement = placement;
      _interstitial = ad;
    } catch (error, stack) {
      debugPrint('preloadInterstitial failed: $error\n$stack');
    }
  }

  @override
  Future<bool> showInterstitial({
    required bool adsRemoved,
    String placement = AdsPlacements.afterSession,
  }) async {
    if (adsRemoved ||
        !AdsRemoteConfig.instance.interstitialAdsEnabled ||
        _fullScreenShowing ||
        _inAfterCloseCooldown) {
      return false;
    }
    if (!await _canUseAds()) return false;

    final minInterval = AdsRemoteConfig.instance.interstitialMinInterval;
    if (!interstitialFrequencyAllows(
      lastShown: _lastFullScreenAt,
      minInterval: minInterval,
      now: DateTime.now(),
    )) {
      return false;
    }

    _interstitialShowAttempts++;
    if (AdsRemoteConfig.instance.interstitialSkipFirst &&
        _interstitialShowAttempts == 1) {
      return false;
    }

    if (_interstitial == null || _interstitialPlacement != placement) {
      await preloadInterstitial(placement: placement);
    }
    final ad = _interstitial;
    if (ad == null) return false;

    _interstitial = null;
    _interstitialPlacement = null;
    _fullScreenShowing = true;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (shown) {
        shown.dispose();
        _fullScreenShowing = false;
        _lastFullScreenAt = DateTime.now();
        if (!done.isCompleted) done.complete(true);
      },
      onAdFailedToShowFullScreenContent: (shown, error) {
        debugPrint('Interstitial show failed: $error');
        shown.dispose();
        _fullScreenShowing = false;
        if (!done.isCompleted) done.complete(false);
      },
    );

    try {
      await ad.show();
      return done.future;
    } catch (error, stack) {
      debugPrint('showInterstitial failed: $error\n$stack');
      ad.dispose();
      _fullScreenShowing = false;
      if (!done.isCompleted) done.complete(false);
      return false;
    }
  }

  @override
  Future<void> preloadRewarded({
    String placement = AdsPlacements.dailyChallenge,
  }) async {
    if (_rewarded != null && _rewardedPlacement == placement) return;
    final unitId = _config.rewardedUnitId(placement);
    if (unitId == null) return;
    if (!await _canUseAds()) return;
    if (_rewardedLoadAttempts > _config.maxRetries) return;

    try {
      _rewardedRetry?.cancel();
      _rewarded?.dispose();
      _rewarded = null;
      final completer = Completer<RewardedAd?>();
      await RewardedAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: completer.complete,
          onAdFailedToLoad: (error) {
            debugPrint('Rewarded no-fill/fail [$placement]: $error');
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      );
      final ad = await completer.future.timeout(
        _config.requestTimeout,
        onTimeout: () => null,
      );
      if (ad == null) {
        _rewardedLoadAttempts++;
        _scheduleRewardedRetry(placement);
        return;
      }
      _rewardedLoadAttempts = 0;
      _rewardedPlacement = placement;
      _rewarded = ad;
    } catch (error, stack) {
      debugPrint('preloadRewarded failed: $error\n$stack');
    }
  }

  @override
  Future<bool> showRewarded({
    required String placement,
    required void Function() onEarned,
  }) async {
    if (_fullScreenShowing || _inAfterCloseCooldown) return false;
    if (!await _canUseAds()) return false;

    if (_rewarded == null || _rewardedPlacement != placement) {
      await preloadRewarded(placement: placement);
    }
    final ad = _rewarded;
    if (ad == null) return false;

    _rewarded = null;
    _rewardedPlacement = null;
    _fullScreenShowing = true;
    var earned = false;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (shown) {
        shown.dispose();
        _fullScreenShowing = false;
        _lastFullScreenAt = DateTime.now();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (shown, error) {
        debugPrint('Rewarded show failed: $error');
        shown.dispose();
        _fullScreenShowing = false;
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
      return done.future;
    } catch (error, stack) {
      debugPrint('showRewarded failed: $error\n$stack');
      ad.dispose();
      _fullScreenShowing = false;
      if (!done.isCompleted) done.complete(false);
      return false;
    }
  }

  Future<bool> _canUseAds() async {
    if (!_config.isEnabled) return false;
    if (!AdsRemoteConfig.instance.adsEnabled) return false;
    if (!_network.isOnline) return false;
    return _ensureSdk();
  }

  Future<bool> _ensureSdk() async {
    if (_sdkInitialized) return true;
    if (!_network.isOnline || !_config.isEnabled) return false;
    if (_initializing) return _sdkInitialized;
    _initializing = true;
    try {
      await MobileAds.instance.initialize().timeout(_sdkInitTimeout);
      _sdkInitialized = true;
    } catch (error, stack) {
      debugPrint('MobileAds.initialize failed: $error\n$stack');
      _sdkInitialized = false;
    } finally {
      _initializing = false;
    }
    return _sdkInitialized;
  }

  void _clearInterstitial() {
    _interstitial?.dispose();
    _interstitial = null;
    _interstitialPlacement = null;
  }

  void _scheduleInterstitialRetry(String placement) {
    if (!_network.isOnline) return;
    if (_interstitialLoadAttempts > _config.maxRetries) return;
    _interstitialRetry?.cancel();
    final delay = _config.retryBackoff * _interstitialLoadAttempts;
    _interstitialRetry = Timer(delay, () {
      unawaited(preloadInterstitial(placement: placement));
    });
  }

  void _scheduleRewardedRetry(String placement) {
    if (!_network.isOnline) return;
    if (_rewardedLoadAttempts > _config.maxRetries) return;
    _rewardedRetry?.cancel();
    final delay = _config.retryBackoff * _rewardedLoadAttempts;
    _rewardedRetry = Timer(delay, () {
      unawaited(preloadRewarded(placement: placement));
    });
  }
}
