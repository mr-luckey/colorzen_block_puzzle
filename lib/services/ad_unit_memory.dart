import 'package:hive_flutter/hive_flutter.dart';

import 'package:colorzen_block_puzzle/core/constants/hive_constants.dart';

/// Remembers which AdMob unit ID last loaded successfully per ad type,
/// so the next waterfall starts with a known-good ID.
class AdUnitMemory {
  AdUnitMemory._();

  static const _bannerKey = 'ad_pref_banner';
  static const _interstitialKey = 'ad_pref_interstitial';
  static const _rewardedKey = 'ad_pref_rewarded';

  static Box<dynamic> get _box => Hive.box(HiveBoxNames.engagement);

  /// Preferred ID first, then the rest in list order (no duplicates).
  static List<String> orderedIds(List<String> ids, String memoryKey) {
    if (ids.isEmpty) return const [];
    final preferred = _box.get(memoryKey) as String?;
    if (preferred == null || !ids.contains(preferred)) {
      return List<String>.from(ids);
    }
    return [
      preferred,
      ...ids.where((id) => id != preferred),
    ];
  }

  static List<String> bannerOrder(List<String> ids) =>
      orderedIds(ids, _bannerKey);

  static List<String> interstitialOrder(List<String> ids) =>
      orderedIds(ids, _interstitialKey);

  static List<String> rewardedOrder(List<String> ids) =>
      orderedIds(ids, _rewardedKey);

  static Future<void> rememberBanner(String id) =>
      _box.put(_bannerKey, id);

  static Future<void> rememberInterstitial(String id) =>
      _box.put(_interstitialKey, id);

  static Future<void> rememberRewarded(String id) =>
      _box.put(_rewardedKey, id);
}
