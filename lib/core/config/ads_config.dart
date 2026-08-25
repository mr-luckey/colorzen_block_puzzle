import 'package:flutter/foundation.dart';

/// Official Google sample units. Use only when [AdsConfig.testMode] is true.
abstract final class GoogleTestAdUnits {
  static const androidAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const iosAppId = 'ca-app-pub-3940256099942544~1458002511';

  static const androidBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const androidInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const androidRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static const iosBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const iosInterstitial = 'ca-app-pub-3940256099942544/4411468910';
  static const iosRewarded = 'ca-app-pub-3940256099942544/1712485313';
}

/// Named placements → one index in the matching unit list. Not a waterfall.
abstract final class AdsPlacements {
  static const home = 'home';
  static const game = 'game';
  static const settings = 'settings';
  static const afterSession = 'after_session';
  static const afterExit = 'after_exit';
  static const dailyChallenge = 'daily_challenge';
  static const gameOverBonus = 'game_over_bonus';
  static const themeUnlock = 'theme_unlock';
}

/// Android production units from this project's AdMob account.
/// iOS production units are not in the repo — lists stay empty until supplied.
abstract final class AdMobProductionUnits {
  static const androidAppId = 'ca-app-pub-5561438827097019~3867868442';

  static const androidBanners = [
    'ca-app-pub-5561438827097019/6937984991', // home
    'ca-app-pub-5561438827097019/5624903328', // game
    'ca-app-pub-5561438827097019/3521338375', // settings
    'ca-app-pub-5561438827097019/2171643395',
    'ca-app-pub-5561438827097019/9895175036',
  ];

  static const androidInterstitials = [
    'ca-app-pub-5561438827097019/1685658317', // after_session
    'ca-app-pub-5561438827097019/9839334719', // after_exit
    'ca-app-pub-5561438827097019/8059494974',
    'ca-app-pub-5561438827097019/4774710295',
    'ca-app-pub-5561438827097019/8545480050',
  ];

  static const androidRewarded = [
    'ca-app-pub-5561438827097019/1709709043', // daily_challenge
    'ca-app-pub-5561438827097019/2148546951', // game_over_bonus
    'ca-app-pub-5561438827097019/9835465283', // theme_unlock
    'ca-app-pub-5561438827097019/3381737579',
    'ca-app-pub-5561438827097019/2068655906',
  ];
}

/// Central AdMob configuration. Never invent production IDs.
///
/// Unit lists hold up to five IDs. Placements map a screen/feature onto one
/// index. Empty strings disable that slot. There is no automatic fill waterfall.
class AdsConfig {
  const AdsConfig({
    this.isEnabled = true,
    this.testMode = kDebugMode,
    this.bannerEnabled = true,
    this.interstitialEnabled = true,
    this.rewardedEnabled = true,
    this.bannerAdUnits = const [],
    this.interstitialAdUnits = const [],
    this.rewardedAdUnits = const [],
    this.bannerPlacements = const {AdsPlacements.home: 0},
    this.interstitialPlacements = const {AdsPlacements.afterSession: 0},
    this.rewardedPlacements = const {AdsPlacements.dailyChallenge: 0},
    this.minimumInterstitialInterval = const Duration(seconds: 180),
    this.maxRetries = 2,
    this.retryBackoff = const Duration(seconds: 30),
    this.requestTimeout = const Duration(seconds: 10),
  });

  final bool isEnabled;
  final bool testMode;
  final bool bannerEnabled;
  final bool interstitialEnabled;
  final bool rewardedEnabled;

  final List<String> bannerAdUnits;
  final List<String> interstitialAdUnits;
  final List<String> rewardedAdUnits;

  /// Placement name → index into the matching unit list.
  final Map<String, int> bannerPlacements;
  final Map<String, int> interstitialPlacements;
  final Map<String, int> rewardedPlacements;

  final Duration minimumInterstitialInterval;
  final int maxRetries;
  final Duration retryBackoff;
  final Duration requestTimeout;

  String? bannerUnitId(String placement) => _unit(
        bannerAdUnits,
        bannerPlacements[placement],
        bannerEnabled,
        _AdFormat.banner,
      );

  String? interstitialUnitId(String placement) => _unit(
        interstitialAdUnits,
        interstitialPlacements[placement],
        interstitialEnabled,
        _AdFormat.interstitial,
      );

  String? rewardedUnitId(String placement) => _unit(
        rewardedAdUnits,
        rewardedPlacements[placement],
        rewardedEnabled,
        _AdFormat.rewarded,
      );

  String? _unit(
    List<String> units,
    int? index,
    bool enabled,
    _AdFormat format,
  ) {
    if (!isEnabled || !enabled || index == null || index < 0) return null;
    if (testMode) return _testIdFor(format);
    if (index >= units.length) return null;
    final id = units[index].trim();
    return id.isEmpty ? null : id;
  }

  String _testIdFor(_AdFormat format) {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    return switch (format) {
      _AdFormat.banner =>
        ios ? GoogleTestAdUnits.iosBanner : GoogleTestAdUnits.androidBanner,
      _AdFormat.interstitial => ios
          ? GoogleTestAdUnits.iosInterstitial
          : GoogleTestAdUnits.androidInterstitial,
      _AdFormat.rewarded =>
        ios ? GoogleTestAdUnits.iosRewarded : GoogleTestAdUnits.androidRewarded,
    };
  }
}

enum _AdFormat { banner, interstitial, rewarded }

/// ColorZen production config. Debug/tests always use Google sample units.
AdsConfig colorZenAdsConfig({TargetPlatform? platform}) {
  final ios = (platform ?? defaultTargetPlatform) == TargetPlatform.iOS;
  return AdsConfig(
    isEnabled: true,
    testMode: kDebugMode,
    bannerEnabled: true,
    interstitialEnabled: true,
    rewardedEnabled: true,
    bannerAdUnits: ios
        ? const ['', '', '', '', '']
        : AdMobProductionUnits.androidBanners,
    interstitialAdUnits: ios
        ? const ['', '', '', '', '']
        : AdMobProductionUnits.androidInterstitials,
    rewardedAdUnits: ios
        ? const ['', '', '', '', '']
        : AdMobProductionUnits.androidRewarded,
    bannerPlacements: const {
      AdsPlacements.home: 0,
      AdsPlacements.game: 1,
      AdsPlacements.settings: 2,
    },
    interstitialPlacements: const {
      AdsPlacements.afterSession: 0,
      AdsPlacements.afterExit: 1,
    },
    rewardedPlacements: const {
      AdsPlacements.dailyChallenge: 0,
      AdsPlacements.gameOverBonus: 1,
      AdsPlacements.themeUnlock: 2,
    },
    minimumInterstitialInterval: const Duration(seconds: 180),
    maxRetries: 2,
    retryBackoff: const Duration(seconds: 30),
  );
}

/// Pure frequency helper — no SDK, safe for unit tests.
bool interstitialFrequencyAllows({
  required DateTime? lastShown,
  required Duration minInterval,
  required DateTime now,
}) {
  if (lastShown == null) return true;
  return now.difference(lastShown) >= minInterval;
}
