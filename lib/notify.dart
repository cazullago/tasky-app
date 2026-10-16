import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications. EVERYTHING here is guarded: init and scheduling
/// never throw, so a plugin failure can never crash startup or the app.
/// Uses inexact scheduling — no exact-alarm permission needed.
class NotifyService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _ready = false;
  static bool get ready => _ready;

  /// Safe to call from main(): never throws.
  static Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        settings: const InitializationSettings(android: android),
        onDidReceiveNotificationResponse: (_) {},
      );
      const channel = AndroidNotificationChannel(
        'tasky_reminders',
        'Tasky reminders',
        description: 'Task reminders from your Tasky assistants',
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      _ready = true;
    } catch (e) {
      // Feature silently off — app keeps running.
      debugPrint('Tasky notifications unavailable: $e');
      _ready = false;
    }
  }

  /// Ask the system for notification permission. Never throws.
  static Future<bool> requestPermission() async {
    try {
      final impl = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await impl?.requestNotificationsPermission() ?? false;
    } catch (e) {
      debugPrint('Tasky notification permission request failed: $e');
      return false;
    }
  }

  /// Schedule a reminder. Silently no-ops when notifications are unavailable.
  static Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    try {
      if (!_ready) return;
      if (when.isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
        return;
      }
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'tasky_reminders',
          'Tasky reminders',
          channelDescription: 'Task reminders from your Tasky assistants',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );
    } catch (e) {
      debugPrint('Tasky scheduleReminder failed: $e');
    }
  }

  /// Show an immediate notification (e.g. study timer done). Never throws.
  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      if (!_ready) return;
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'tasky_reminders',
          'Tasky reminders',
          channelDescription: 'Task reminders from your Tasky assistants',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      await _plugin.show(id: id, title: title, body: body, notificationDetails: details);
    } catch (e) {
      debugPrint('Tasky showNow failed: $e');
    }
  }

  /// Cancel a scheduled reminder. Never throws.
  static Future<void> cancel(int id) async {
    try {
      if (!_ready) return;
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Tasky cancel notification failed: $e');
    }
  }
}
