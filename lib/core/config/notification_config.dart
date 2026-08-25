class NotificationMessage {
  const NotificationMessage({
    required this.id,
    required this.title,
    required this.body,
  });

  final String id;
  final String title;
  final String body;

  factory NotificationMessage.fromJson(Map<String, dynamic> json) {
    return NotificationMessage(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }
}

enum NotificationRotationMode { alternate, sequential }

class NotificationConfig {
  const NotificationConfig({
    this.enabled = true,
    this.assetPath = 'assets/notifications/notifications.json',
    this.scheduleTimes = const ['17:00', '21:00'],
    this.rotationMode = NotificationRotationMode.alternate,
    this.daysToSchedule = 14,
    this.androidChannelId = 'daily_local',
    this.androidChannelName = 'Daily reminders',
  });

  final bool enabled;
  final String assetPath;

  /// Local clock times `HH:mm`. Alternating mode walks this list by day index.
  final List<String> scheduleTimes;
  final NotificationRotationMode rotationMode;
  final int daysToSchedule;
  final String androidChannelId;
  final String androidChannelName;

  /// Day 0 → first time, day 1 → second time, then repeats when alternate.
  ({int hour, int minute})? timeForDay(int dayIndex) {
    if (scheduleTimes.isEmpty) return null;
    final token = rotationMode == NotificationRotationMode.alternate
        ? scheduleTimes[dayIndex % scheduleTimes.length]
        : scheduleTimes[0];
    final parts = token.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return (hour: hour, minute: minute);
  }
}
