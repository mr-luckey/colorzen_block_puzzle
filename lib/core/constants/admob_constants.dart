import 'dart:io';

class AdMobConstants {
  /// ──── SET TO false BEFORE PRODUCTION RELEASE ────
  static const bool kUseTestAds = false;

  // Google-provided test unit IDs (work on any device, no policy risk).
  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  // Production AdMob units (Android). iOS still uses Google test units until App Store setup.
  // Waterfall: try remembered ID first, then index 0→4 until one loads (one request at a time).
  // Fullscreen: only one interstitial OR rewarded may be on screen; cancel starts a short cooldown.

  static const List<String> kBannerAndroid = [
    'ca-app-pub-6619866004331477/5145602152',
    'ca-app-pub-6619866004331477/7036383849',
    'ca-app-pub-6619866004331477/8099068556',
    'ca-app-pub-6619866004331477/5472905218',
    'ca-app-pub-6619866004331477/2846741871',
  ];

  static const List<String> kBannerIOS = [
    'ca-app-pub-3940256099942544/2934735716',
    'ca-app-pub-3940256099942544/2934735716',
    'ca-app-pub-3940256099942544/2934735716',
    'ca-app-pub-3940256099942544/2934735716',
    'ca-app-pub-3940256099942544/2934735716',
  ];

  static const List<String> kInterstitialAndroid = [
    'ca-app-pub-6619866004331477/5201442473',
    'ca-app-pub-6619866004331477/3832520487',
    'ca-app-pub-6619866004331477/1784057161',
    'ca-app-pub-6619866004331477/4856943061',
    'ca-app-pub-6619866004331477/4121506541',
  ];

  static const List<String> kInterstitialIOS = [
    'ca-app-pub-3940256099942544/4411468910',
    'ca-app-pub-3940256099942544/4411468910',
    'ca-app-pub-3940256099942544/4411468910',
    'ca-app-pub-3940256099942544/4411468910',
    'ca-app-pub-3940256099942544/4411468910',
  ];

  static const List<String> kRewardedAndroid = [
    'ca-app-pub-6619866004331477/5442327079',
    'ca-app-pub-6619866004331477/1592485470',
    'ca-app-pub-6619866004331477/2655170181',
    'ca-app-pub-6619866004331477/5340158797',
    'ca-app-pub-6619866004331477/6653240463',
  ];

  static const List<String> kRewardedIOS = [
    'ca-app-pub-3940256099942544/1712485313',
    'ca-app-pub-3940256099942544/1712485313',
    'ca-app-pub-3940256099942544/1712485313',
    'ca-app-pub-3940256099942544/1712485313',
    'ca-app-pub-3940256099942544/1712485313',
  ];

  // Must match AndroidManifest com.google.android.gms.ads.APPLICATION_ID
  static const String kAppIdAndroid = 'ca-app-pub-6619866004331477~5305314441';
  static const String kAppIdIOS = 'ca-app-pub-3940256099942544~1458002511';

  static List<String> get bannerIds => kUseTestAds
      ? [_testBanner]
      : Platform.isIOS
          ? kBannerIOS
          : kBannerAndroid;

  static List<String> get interstitialIds => kUseTestAds
      ? [_testInterstitial]
      : Platform.isIOS
          ? kInterstitialIOS
          : kInterstitialAndroid;

  static List<String> get rewardedIds => kUseTestAds
      ? [_testRewarded]
      : Platform.isIOS
          ? kRewardedIOS
          : kRewardedAndroid;
}
