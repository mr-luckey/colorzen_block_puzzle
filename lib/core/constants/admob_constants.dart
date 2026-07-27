import 'dart:io';

class AdMobConstants {
  // Production AdMob units (Android). iOS still uses Google test units until App Store setup.
  // Waterfall: try remembered ID first, then index 0→4 until one loads (one request at a time).
  // Fullscreen: only one interstitial OR rewarded may be on screen; cancel starts a short cooldown.

  static const List<String> kBannerAndroid = [
    'ca-app-pub-5561438827097019/6937984991',
    'ca-app-pub-5561438827097019/5624903328',
    'ca-app-pub-5561438827097019/3521338375',
    'ca-app-pub-5561438827097019/2171643395',
    'ca-app-pub-5561438827097019/9895175036',
  ];

  static const List<String> kBannerIOS = [
    'ca-app-pub-3940256099942544/2934735716',
    'ca-app-pub-3940256099942544/2934735716',
    'ca-app-pub-3940256099942544/2934735716',
    'ca-app-pub-3940256099942544/2934735716',
    'ca-app-pub-3940256099942544/2934735716',
  ];

  static const List<String> kInterstitialAndroid = [
    'ca-app-pub-5561438827097019/1685658317',
    'ca-app-pub-5561438827097019/9839334719',
    'ca-app-pub-5561438827097019/8059494974',
    'ca-app-pub-5561438827097019/4774710295',
    'ca-app-pub-5561438827097019/8545480050',
  ];

  static const List<String> kInterstitialIOS = [
    'ca-app-pub-3940256099942544/4411468910',
    'ca-app-pub-3940256099942544/4411468910',
    'ca-app-pub-3940256099942544/4411468910',
    'ca-app-pub-3940256099942544/4411468910',
    'ca-app-pub-3940256099942544/4411468910',
  ];

  static const List<String> kRewardedAndroid = [
    'ca-app-pub-5561438827097019/1709709043',
    'ca-app-pub-5561438827097019/2148546951',
    'ca-app-pub-5561438827097019/9835465283',
    'ca-app-pub-5561438827097019/3381737579',
    'ca-app-pub-5561438827097019/2068655906',
  ];

  static const List<String> kRewardedIOS = [
    'ca-app-pub-3940256099942544/1712485313',
    'ca-app-pub-3940256099942544/1712485313',
    'ca-app-pub-3940256099942544/1712485313',
    'ca-app-pub-3940256099942544/1712485313',
    'ca-app-pub-3940256099942544/1712485313',
  ];

  // Must match AndroidManifest com.google.android.gms.ads.APPLICATION_ID
  static const String kAppIdAndroid = 'ca-app-pub-5561438827097019~3867868442';
  static const String kAppIdIOS = 'ca-app-pub-3940256099942544~1458002511';

  static List<String> get bannerIds =>
      Platform.isIOS ? kBannerIOS : kBannerAndroid;

  static List<String> get interstitialIds =>
      Platform.isIOS ? kInterstitialIOS : kInterstitialAndroid;

  static List<String> get rewardedIds =>
      Platform.isIOS ? kRewardedIOS : kRewardedAndroid;
}
