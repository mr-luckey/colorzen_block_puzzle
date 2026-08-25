import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'package:colorzen_block_puzzle/core/config/analytics_config.dart';

/// Central analytics facade. Never throw to callers. Never send PII.
class AnalyticsService {
  AnalyticsService({
    AnalyticsConfig config = const AnalyticsConfig(),
    FirebaseAnalytics? analytics,
  })  : _config = config,
        _provided = analytics;

  final AnalyticsConfig _config;
  final FirebaseAnalytics? _provided;
  FirebaseAnalytics? _resolved;

  FirebaseAnalytics? get _analytics {
    if (_provided != null) return _provided;
    if (_resolved != null) return _resolved;
    try {
      _resolved = FirebaseAnalytics.instance;
      return _resolved;
    } catch (error, stack) {
      debugPrint('Analytics unavailable: $error\n$stack');
      return null;
    }
  }

  Future<void> init() async {
    if (!_config.enabled) return;
    try {
      await _analytics?.setAnalyticsCollectionEnabled(true);
    } catch (error, stack) {
      debugPrint('Analytics init failed: $error\n$stack');
    }
  }

  void logLevelStarted({
    int? levelNumber,
    String? difficulty,
    int? attemptNumber,
    String? source,
  }) {
    logEvent(AnalyticsConfig.eventLevelStarted, {
      'level_number': ?levelNumber,
      'difficulty': ?difficulty,
      'attempt_number': ?attemptNumber,
      'source': ?source,
    });
  }

  void logLevelCompleted({
    int? levelNumber,
    String? difficulty,
    int? moves,
    int? timeSeconds,
    int? attemptNumber,
    String? source,
  }) {
    logEvent(AnalyticsConfig.eventLevelCompleted, {
      'level_number': ?levelNumber,
      'difficulty': ?difficulty,
      'moves': ?moves,
      'time_seconds': ?timeSeconds,
      'attempt_number': ?attemptNumber,
      'source': ?source,
    });
  }

  void logLevelFailed({
    int? levelNumber,
    String? difficulty,
    int? moves,
    int? timeSeconds,
    int? attemptNumber,
    String? source,
  }) {
    logEvent(AnalyticsConfig.eventLevelFailed, {
      'level_number': ?levelNumber,
      'difficulty': ?difficulty,
      'moves': ?moves,
      'time_seconds': ?timeSeconds,
      'attempt_number': ?attemptNumber,
      'source': ?source,
    });
  }

  void logLevelAbandoned({
    int? levelNumber,
    String? difficulty,
    String? source,
  }) {
    logEvent(AnalyticsConfig.eventLevelAbandoned, {
      'level_number': ?levelNumber,
      'difficulty': ?difficulty,
      'source': ?source,
    });
  }

  void logHintUsed({int? levelNumber, String? source}) {
    logEvent(AnalyticsConfig.eventHintUsed, {
      'level_number': ?levelNumber,
      'source': ?source,
    });
  }

  void logRewardClaimed({String? rewardType, String? source}) {
    logEvent(AnalyticsConfig.eventRewardClaimed, {
      'reward_type': ?rewardType,
      'source': ?source,
    });
  }

  void logDailyRewardClaimed({int? day, String? source}) {
    logEvent(AnalyticsConfig.eventDailyRewardClaimed, {
      'day': ?day,
      'source': ?source,
    });
  }

  void logNotificationOpened({
    String? notificationId,
    String? source,
  }) {
    logEvent(AnalyticsConfig.eventNotificationOpened, {
      'notification_id': ?notificationId,
      'source': ?source,
    });
  }

  void logNotificationScheduled({int? count, String? source}) {
    logEvent(AnalyticsConfig.eventNotificationScheduled, {
      'count': ?count,
      'source': ?source,
    });
  }

  void logRewardedAdCompleted({String? placement, String? source}) {
    logEvent(AnalyticsConfig.eventRewardedAdCompleted, {
      'placement': ?placement,
      'source': ?source,
    });
  }

  /// Fire-and-forget. Callers must not await this on gameplay hot paths.
  void logEvent(String name, [Map<String, Object>? parameters]) {
    if (!_config.enabled) return;
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      // ignore: discarded_futures
      analytics.logEvent(
        name: name,
        parameters: parameters == null
            ? null
            : sanitizeAnalyticsParameters(parameters),
      );
    } catch (error, stack) {
      debugPrint('Analytics event "$name" failed: $error\n$stack');
    }
  }
}
