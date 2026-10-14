import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'store.dart';

/// Local notifications for tasks, reminders, and calendar events.
/// Uses inexact scheduling so no exact-alarm permission is needed.
class NotifyService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (_) {},
    );
    const channel = AndroidNotificationChannel(
      'tasky_reminders',
      'Tasky reminders',
      description: 'Task due dates, reminders, and calendar events',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    _ready = true;
  }

  /// Returns true when the permission was granted.
  static Future<bool> requestPermission() async {
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await impl?.requestNotificationsPermission() ?? false;
  }

  static Future<void> _schedule(
      int id, String title, String body, DateTime when) async {
    if (id > 40) return; // keep the queue bounded
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'tasky_reminders',
          'Tasky reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static TimeOfDay _parseTime(String? hhmm) {
    if (hhmm == null) return const TimeOfDay(hour: 9, minute: 0);
    final p = hhmm.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  /// Rebuilds all scheduled notifications from current store data.
  static Future<void> reschedule(TaskyStore s) async {
    await _plugin.cancelAll();
    if (!s.notificationsEnabled) return;
    final now = DateTime.now();
    final today = dateOnly(now);
    int id = 0;

    if (s.notifyUpcoming || s.notifyOverdue) {
      for (final t in s.tasks) {
        if (t.completed) continue;
        // Overdue: nudge once, now.
        if (s.notifyOverdue &&
            t.dueDate != null &&
            dateOnly(t.dueDate!).isBefore(today) &&
            t.recurrence == 'none') {
          await _schedule(id++, 'Overdue: ${t.title}',
              'This was due ${_shortDate(t.dueDate!)}. Tap to review.', now.add(const Duration(seconds: 5)));
          continue;
        }
        if (!s.notifyUpcoming || t.dueDate == null) continue;
        // First upcoming occurrence within 7 days.
        for (var i = 0; i < 7; i++) {
          final day = today.add(Duration(days: i));
          if (t.occursOn(day)) {
            final tod = _parseTime(t.dueTime);
            final when = DateTime(day.year, day.month, day.day, tod.hour, tod.minute);
            if (when.isAfter(now)) {
              await _schedule(
                  id++,
                  t.isReminder ? 'Reminder' : 'Task due soon',
                  '${t.title} · ${_shortDate(day)}',
                  when);
            }
            break;
          }
        }
      }
    }

    if (s.notifyEvents) {
      for (final e in s.events) {
        for (var i = 0; i < 7; i++) {
          final day = today.add(Duration(days: i));
          if (e.occursOn(day)) {
            final when = DateTime(
                    day.year, day.month, day.day, e.start.hour, e.start.minute)
                .subtract(const Duration(minutes: 30));
            if (when.isAfter(now)) {
              await _schedule(id++, 'Upcoming event',
                  '${e.title} starts at ${_hm(e.start)}', when);
            }
            break;
          }
        }
      }
    }
  }

  static String _shortDate(DateTime d) => '${d.month}/${d.day}/${d.year}';

  static String _hm(DateTime d) {
    var h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:${d.minute.toString().padLeft(2, '0')} $ap';
  }
}
