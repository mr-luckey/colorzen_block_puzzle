import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:colorzen_block_puzzle/core/config/notification_config.dart';

typedef NotificationTapCallback = void Function(String? payload);

/// Fully offline local notifications. Idempotent. Device-local timezone.
class LocalNotificationService {
  LocalNotificationService({
    NotificationConfig config = const NotificationConfig(),
    FlutterLocalNotificationsPlugin? plugin,
    this.onTap,
  })  : _config = config,
        _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const fingerprintKey = 'local_notification_fingerprint_v1';

  final NotificationConfig _config;
  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationTapCallback? onTap;

  bool _initialized = false;

  Future<void> init() async {
    if (!_config.enabled || _initialized) return;
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(await localTimezoneName()));

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (response) {
          onTap?.call(response.payload);
        },
      );
      _initialized = true;
    } catch (error, stack) {
      debugPrint('LocalNotificationService.init failed: $error\n$stack');
    }
  }

  Future<bool> requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final androidOk = await android?.requestNotificationsPermission() ?? true;
      final iosOk = await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          true;
      return androidOk && iosOk;
    } catch (error, stack) {
      debugPrint('Notification permission failed: $error\n$stack');
      return false;
    }
  }

  /// Safe to call on every launch. Does not create duplicates.
  Future<int> scheduleNotifications() async {
    if (!_config.enabled) return 0;
    await init();
    if (!_initialized) return 0;

    final allowed = await requestPermission();
    if (!allowed) return 0;

    try {
      final messages = await loadMessages();
      if (messages.isEmpty) return 0;

      final fingerprint = await buildFingerprint(messages);
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(fingerprintKey) == fingerprint) {
        final pending = await _plugin.pendingNotificationRequests();
        if (pending.isNotEmpty) return pending.length;
      }

      await _plugin.cancelAll();
      final count = await _scheduleUpcoming(messages);
      await prefs.setString(fingerprintKey, fingerprint);
      return count;
    } catch (error, stack) {
      debugPrint('scheduleNotifications failed: $error\n$stack');
      return 0;
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(fingerprintKey);
    } catch (error, stack) {
      debugPrint('cancelAll notifications failed: $error\n$stack');
    }
  }

  @visibleForTesting
  Future<List<NotificationMessage>> loadMessages() async {
    final raw = await rootBundle.loadString(_config.assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = decoded['notifications'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(NotificationMessage.fromJson)
        .where((m) => m.id.isNotEmpty && m.title.isNotEmpty)
        .toList();
  }

  Future<int> _scheduleUpcoming(List<NotificationMessage> messages) async {
    var scheduled = 0;
    final now = tz.TZDateTime.now(tz.local);
    for (var day = 0; day < _config.daysToSchedule; day++) {
      final time = _config.timeForDay(day);
      if (time == null) continue;
      var fire = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      ).add(Duration(days: day));
      if (!fire.isAfter(now)) continue;
      final message = messages[day % messages.length];
      await _plugin.zonedSchedule(
        day + 1,
        message.title,
        message.body,
        fire,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _config.androidChannelId,
            _config.androidChannelName,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: message.id,
      );
      scheduled++;
    }
    return scheduled;
  }

  @visibleForTesting
  static Future<String> localTimezoneName() async {
    return FlutterTimezone.getLocalTimezone();
  }

  @visibleForTesting
  Future<String> buildFingerprint(List<NotificationMessage> messages) async {
    return fingerprintFor(
      timeZone: await localTimezoneName(),
      config: _config,
      messages: messages,
    );
  }

  @visibleForTesting
  static String fingerprintFor({
    required String timeZone,
    required NotificationConfig config,
    required List<NotificationMessage> messages,
  }) {
    return jsonEncode({
      'tz': timeZone,
      'times': config.scheduleTimes,
      'mode': config.rotationMode.name,
      'days': config.daysToSchedule,
      'plugin': 'v1',
      'messages': messages
          .map((m) => {'id': m.id, 'title': m.title, 'body': m.body})
          .toList(),
    });
  }
}
