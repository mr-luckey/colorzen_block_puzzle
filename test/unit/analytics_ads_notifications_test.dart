import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:colorzen_block_puzzle/core/config/ads_config.dart';
import 'package:colorzen_block_puzzle/core/config/analytics_config.dart';
import 'package:colorzen_block_puzzle/core/config/notification_config.dart';
import 'package:colorzen_block_puzzle/services/local_notification_service.dart';
import 'package:colorzen_block_puzzle/services/network_guard.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() {
  group('AdsConfig placements', () {
    test('maps named placements to configured production IDs', () {
      const config = AdsConfig(
        testMode: false,
        bannerAdUnits: AdMobProductionUnits.androidBanners,
        interstitialAdUnits: AdMobProductionUnits.androidInterstitials,
        rewardedAdUnits: AdMobProductionUnits.androidRewarded,
        bannerPlacements: {
          AdsPlacements.home: 0,
          AdsPlacements.game: 1,
          AdsPlacements.settings: 2,
        },
        interstitialPlacements: {
          AdsPlacements.afterSession: 0,
          AdsPlacements.afterExit: 1,
        },
        rewardedPlacements: {
          AdsPlacements.dailyChallenge: 0,
          AdsPlacements.gameOverBonus: 1,
          AdsPlacements.themeUnlock: 2,
        },
      );

      expect(
        config.bannerUnitId(AdsPlacements.home),
        AdMobProductionUnits.androidBanners[0],
      );
      expect(
        config.bannerUnitId(AdsPlacements.game),
        AdMobProductionUnits.androidBanners[1],
      );
      expect(
        config.interstitialUnitId(AdsPlacements.afterExit),
        AdMobProductionUnits.androidInterstitials[1],
      );
      expect(
        config.rewardedUnitId(AdsPlacements.themeUnlock),
        AdMobProductionUnits.androidRewarded[2],
      );
    });

    test('empty or missing placement IDs disable that slot', () {
      const config = AdsConfig(
        testMode: false,
        bannerAdUnits: ['ca-app-pub-test/home', '', ''],
        bannerPlacements: {
          AdsPlacements.home: 0,
          AdsPlacements.game: 1,
          AdsPlacements.settings: 9,
        },
      );
      expect(config.bannerUnitId(AdsPlacements.home), 'ca-app-pub-test/home');
      expect(config.bannerUnitId(AdsPlacements.game), isNull);
      expect(config.bannerUnitId(AdsPlacements.settings), isNull);
      expect(config.bannerUnitId('unknown'), isNull);
    });

    test('testMode uses official Google sample units only', () {
      const config = AdsConfig(
        testMode: true,
        bannerAdUnits: AdMobProductionUnits.androidBanners,
        interstitialAdUnits: AdMobProductionUnits.androidInterstitials,
        rewardedAdUnits: AdMobProductionUnits.androidRewarded,
        bannerPlacements: {AdsPlacements.home: 0},
        interstitialPlacements: {AdsPlacements.afterSession: 0},
        rewardedPlacements: {AdsPlacements.dailyChallenge: 0},
      );

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(
        config.bannerUnitId(AdsPlacements.home),
        GoogleTestAdUnits.androidBanner,
      );
      expect(
        config.interstitialUnitId(AdsPlacements.afterSession),
        GoogleTestAdUnits.androidInterstitial,
      );
      expect(
        config.rewardedUnitId(AdsPlacements.dailyChallenge),
        GoogleTestAdUnits.androidRewarded,
      );
      expect(
        config.bannerUnitId(AdsPlacements.home),
        isNot(AdMobProductionUnits.androidBanners[0]),
      );
    });
  });

  group('interstitial frequency', () {
    test('allows first show and enforces minimum interval', () {
      final now = DateTime(2026, 8, 25, 12);
      expect(
        interstitialFrequencyAllows(
          lastShown: null,
          minInterval: const Duration(seconds: 180),
          now: now,
        ),
        isTrue,
      );
      expect(
        interstitialFrequencyAllows(
          lastShown: now.subtract(const Duration(seconds: 30)),
          minInterval: const Duration(seconds: 180),
          now: now,
        ),
        isFalse,
      );
      expect(
        interstitialFrequencyAllows(
          lastShown: now.subtract(const Duration(seconds: 180)),
          minInterval: const Duration(seconds: 180),
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('NetworkGuard', () {
    test('none is offline; wifi/mobile is usable', () {
      expect(NetworkGuard.usableResults(const []), isFalse);
      expect(
        NetworkGuard.usableResults(const [ConnectivityResult.none]),
        isFalse,
      );
      expect(
        NetworkGuard.usableResults(const [ConnectivityResult.wifi]),
        isTrue,
      );
      expect(
        NetworkGuard.usableResults(const [ConnectivityResult.mobile]),
        isTrue,
      );
    });
  });

  group('NotificationConfig', () {
    test('alternates 17:00 and 21:00 by day index', () {
      const config = NotificationConfig();
      expect(config.timeForDay(0), (hour: 17, minute: 0));
      expect(config.timeForDay(1), (hour: 21, minute: 0));
      expect(config.timeForDay(2), (hour: 17, minute: 0));
      expect(config.timeForDay(3), (hour: 21, minute: 0));
    });
  });

  group('notification fingerprint', () {
    test('same payload is stable; timezone or copy changes it', () {
      const messages = [
        NotificationMessage(id: 'daily_001', title: 'A', body: 'B'),
      ];
      const config = NotificationConfig();
      final a = LocalNotificationService.fingerprintFor(
        timeZone: 'Asia/Karachi',
        config: config,
        messages: messages,
      );
      final b = LocalNotificationService.fingerprintFor(
        timeZone: 'Asia/Karachi',
        config: config,
        messages: messages,
      );
      final c = LocalNotificationService.fingerprintFor(
        timeZone: 'America/New_York',
        config: config,
        messages: messages,
      );
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('analytics sanitize', () {
    test('drops PII-like keys and keeps primitives', () {
      final out = sanitizeAnalyticsParameters({
        'score': 12,
        'won': true,
        'mode': 'classic',
        'email': 'hidden@example.com',
        'auth_token': 'secret',
        'extra': ['not', 'primitive'],
      });
      expect(out['score'], 12);
      expect(out['won'], true);
      expect(out['mode'], 'classic');
      expect(out.containsKey('email'), isFalse);
      expect(out.containsKey('auth_token'), isFalse);
      expect(out['extra'], '[not, primitive]');
    });
  });
}
