import 'dart:async';

import 'package:colorzen_block_puzzle/core/constants/admob_constants.dart';
import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
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
  /// Does not change existing game interstitial cooldown behavior.
  void setMenuAdsActive({required bool active, required bool adsRemoved});

  /// Hard lock: while true, menu interstitial never shows (even if Home rebuilds).
  void setInGameplay(bool inGameplay);
}

class AdMobService implements AdService {
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  DateTime? _lastInterstitialShown;
  bool _initialized = false;

  Timer? _menuTimer;
  bool _menuAdsActive = false;
  bool _adsRemoved = false;
  bool _showingMenuAd = false;
  /// Blocks menu interstitials during an active game (Home stays under the route).
  bool _inGameplay = false;

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

  @override
  Future<void> loadInterstitial() async {
    try {
      await InterstitialAd.load(
        adUnitId: AdMobConstants.interstitialId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) => _interstitial = ad,
          onAdFailedToLoad: (_) => _interstitial = null,
        ),
      );
    } catch (_) {
      _interstitial = null;
    }
  }

  @override
  Future<bool> showInterstitial({
    required bool adsRemoved,
    bool ignoreCooldown = false,
  }) async {
    if (adsRemoved) return false;
    final last = _lastInterstitialShown;
    if (!ignoreCooldown &&
        last != null &&
        DateTime.now().difference(last).inMilliseconds <
            AppConstants.interstitialCooldownMs) {
      return false;
    }
    final ad = _interstitial;
    if (ad == null) {
      await loadInterstitial();
      return false;
    }
    _interstitial = null;
    _lastInterstitialShown = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        loadInterstitial();
      },
    );
    await ad.show();
    // Preload next immediately after show starts
    loadInterstitial();
    return true;
  }

  @override
  Future<void> loadRewarded() async {
    try {
      await RewardedAd.load(
        adUnitId: AdMobConstants.rewardedId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) => _rewarded = ad,
          onAdFailedToLoad: (_) => _rewarded = null,
        ),
      );
    } catch (_) {
      _rewarded = null;
    }
  }

  @override
  Future<bool> showRewarded({required void Function() onEarned}) async {
    final ad = _rewarded;
    if (ad == null) {
      await loadRewarded();
      return false;
    }
    _rewarded = null;
    var earned = false;
    // ad.show() resolves when the ad is presented, not when it closes.
    // Wait for dismiss/fail so onUserEarnedReward can set [earned] first.
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewarded();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        loadRewarded();
        if (!done.isCompleted) done.complete(false);
      },
    );
    try {
      await ad.show(
        onUserEarnedReward: (_, __) {
          earned = true;
          onEarned();
        },
      );
    } catch (_) {
      loadRewarded();
      if (!done.isCompleted) done.complete(false);
      return false;
    }
    return done.future;
  }

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
    if (!_menuAdsActive || _adsRemoved || _showingMenuAd || _inGameplay) {
      return;
    }
    final ad = _interstitial;
    if (ad == null) {
      await loadInterstitial();
      return;
    }
    // Re-check after any await / race with GameScreen open.
    if (!_menuAdsActive || _adsRemoved || _inGameplay) return;
    _showingMenuAd = true;
    _interstitial = null;
    // Menu loop uses its own cadence — do not touch game cooldown stamp.
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showingMenuAd = false;
        loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _showingMenuAd = false;
        loadInterstitial();
      },
    );
    try {
      if (_inGameplay || !_menuAdsActive || _adsRemoved) {
        _showingMenuAd = false;
        _interstitial ??= ad;
        return;
      }
      await ad.show();
      loadInterstitial();
    } catch (_) {
      _showingMenuAd = false;
      await loadInterstitial();
    }
  }
}
