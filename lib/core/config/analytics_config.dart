/// Project-specific analytics switches. Keep event names here, not in widgets.
class AnalyticsConfig {
  const AnalyticsConfig({
    this.enabled = true,
  });

  final bool enabled;

  static const eventLevelStarted = 'level_started';
  static const eventLevelCompleted = 'level_completed';
  static const eventLevelFailed = 'level_failed';
  static const eventLevelAbandoned = 'level_abandoned';
  static const eventHintUsed = 'hint_used';
  static const eventRewardClaimed = 'reward_claimed';
  static const eventDailyRewardClaimed = 'daily_reward_claimed';
  static const eventNotificationOpened = 'notification_opened';
  static const eventNotificationScheduled = 'notification_scheduled';
  static const eventRewardedAdCompleted = 'rewarded_ad_completed';
}

/// Drop PII-like keys and coerce values to primitives.
Map<String, Object> sanitizeAnalyticsParameters(Map<String, Object> parameters) {
  const blocked = {
    'password',
    'email',
    'phone',
    'token',
    'auth',
    'payment',
    'card',
  };
  final out = <String, Object>{};
  for (final entry in parameters.entries) {
    final key = entry.key.toLowerCase();
    if (blocked.any(key.contains)) continue;
    final value = entry.value;
    if (value is String || value is num || value is bool) {
      out[entry.key] = value;
    } else {
      out[entry.key] = value.toString();
    }
  }
  return out;
}
