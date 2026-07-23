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
}

class AdMobService implements AdService {
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  DateTime? _lastInterstitialShown;
  bool _initialized = false;

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
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        loadRewarded();
      },
    );
    await ad.show(
      onUserEarnedReward: (_, __) {
        earned = true;
        onEarned();
      },
    );
    return earned;
  }
}
