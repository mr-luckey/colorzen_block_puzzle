import 'dart:io';

class AdMobConstants {
  // Google official test units — replace with production IDs before release.
  static const String kTestBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String kTestBannerIOS =
      'ca-app-pub-3940256099942544/2934735716';
  static const String kTestInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String kTestInterstitialIOS =
      'ca-app-pub-3940256099942544/4411468910';
  static const String kTestRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String kTestRewardedIOS =
      'ca-app-pub-3940256099942544/1712485313';

  static const String kAppIdAndroid =
      'ca-app-pub-3940256099942544~3347511713';
  static const String kAppIdIOS =
      'ca-app-pub-3940256099942544~1458002511';

  static String get bannerId =>
      Platform.isIOS ? kTestBannerIOS : kTestBannerAndroid;

  static String get interstitialId => Platform.isIOS
      ? kTestInterstitialIOS
      : kTestInterstitialAndroid;

  static String get rewardedId =>
      Platform.isIOS ? kTestRewardedIOS : kTestRewardedAndroid;
}
