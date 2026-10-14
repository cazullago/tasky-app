import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Central app state: tasks, events, chat, activities, profile, settings.
/// Persisted to a JSON file on device (survives app updates).
class TaskyStore extends ChangeNotifier {
  List<TaskItem> tasks = [];
  List<CalEvent> events = [];
  List<ChatMsg> messages = [];
  List<ActivityItem> activities = [];

  // Profile
  String userName = 'Alex';
  String email = 'alex@example.com';
  String timezone = 'Asia/Manila';
  String? photoPath;

  // Settings
  String themeMode = 'system'; // light | dark | system
  bool notificationsEnabled = true;
  bool notifyUpcoming = true;
  bool notifyOverdue = true;
  bool notifyEvents = true;
  String aiProvider = 'demo'; // demo | http
  String apiKey = '';
  String baseUrl = 'https://api.openai.com/v1';
  String model = 'gpt-4o-mini';
  String aiTone = 'Friendly';
  bool analyticsEnabled = false;

  bool _loaded = false;
  bool get loaded => _loaded;

  ThemeMode get themeModeValue {
    switch (themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  // ---------- persistence ----------

  Future<File> _dataFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/tasky_data.json');
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userName = prefs.getString('userName') ?? 'Alex';
      email = prefs.getString('email') ?? 'alex@example.com';
      timezone = prefs.getString('timezone') ?? 'Asia/Manila';
      photoPath = prefs.getString('photoPath');
      themeMode = prefs.getString('themeMode') ?? 'system';
      notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      notifyUpcoming = prefs.getBool('notifyUpcoming') ?? true;
      notifyOverdue = prefs.getBool('notifyOverdue') ?? true;
      notifyEvents = prefs.getBool('notifyEvents') ?? true;
      aiProvider = prefs.getString('aiProvider') ?? 'demo';
      apiKey = prefs.getString('apiKey') ?? '';
      baseUrl = prefs.getString('baseUrl') ?? 'https://api.openai.com/v1';
      model = prefs.getString('model') ?? 'gpt-4o-mini';
      aiTone = prefs.getString('aiTone') ?? 'Friendly';
      analyticsEnabled = prefs.getBool('analyticsEnabled') ?? false;

      final file = await _dataFile();
      if (await file.exists()) {
        final j =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        tasks = (j['tasks'] as List? ?? [])
            .map((e) => TaskItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        events = (j['events'] as List? ?? [])
            .map((e) => CalEvent.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        messages = (j['messages'] as List? ?? [])
            .map((e) => ChatMsg.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        activities = (j['activities'] as List? ?? [])
            .map((e) => ActivityItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      final seeded = prefs.getBool('seeded_v1') ?? false;
      if (!seeded) {
        _seedSampleData();
        await prefs.setBool('seeded_v1', true);
      }
    } catch (_) {
      // Corrupt data: start fresh rather than crash.
      _seedSampleData();
    }
    _loaded = true;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', userName);
      await prefs.setString('email', email);
      await prefs.setString('timezone', timezone);
      if (photoPath != null) {
        await prefs.setString('photoPath', photoPath!);
      } else {
        await prefs.remove('photoPath');
      }
      await prefs.setString('themeMode', themeMode);
      await prefs.setBool('notificationsEnabled', notificationsEnabled);
      await prefs.setBool('notifyUpcoming', notifyUpcoming);
      await prefs.setBool('notifyOverdue', notifyOverdue);
      await prefs.setBool('notifyEvents', notifyEvents);
      await prefs.setString('aiProvider', aiProvider);
      await prefs.setString('apiKey', apiKey);
      await prefs.setString('baseUrl', baseUrl);
      await prefs.setString('model', model);
      await prefs.setString('aiTone', aiTone);
      await prefs.setBool('analyticsEnabled', analyticsEnabled);

      final file = await _dataFile();
      await file.writeAsString(jsonEncode({
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
        // keep chat history bounded
        'messages': messages
            .take(200)
            .map((e) => e.toJson())
            .toList(),
        'activities': activities.take(100).map((e) => e.toJson()).toList(),
      }));
    } catch (_) {}
  }

  Future<void> persist() async {
    notifyListeners();
    await _save();
  }

  // ---------- sample seed (idempotent, dates relative to today) ----------

  DateTime _nextFirstOfMonth() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var d = DateTime(now.year, now.month, 1);
    if (!d.isAfter(today)) d = DateTime(now.year, now.month + 1, 1);
    return d;
  }

  void _seedSampleData() {
    final now = DateTime.now();
    final today = dateOnly(now);
    final tmr = today.add(const Duration(days: 1));

    tasks = [
      TaskItem(
        id: uid(),
        title: 'Buy groceries for the week',
        notes: 'Milk, eggs, rice, chicken, vegetables',
        category: 'Shopping',
        priority: 'medium',
        dueDate: today,
        dueTime: '17:00',
      ),
      TaskItem(
        id: uid(),
        title: 'Prepare Q4 business report',
        notes: 'Include TikTok Shop sales summary',
        category: 'Work',
        priority: 'high',
        dueDate: tmr,
        dueTime: '10:00',
      ),
      TaskItem(
        id: uid(),
        title: 'Morning workout',
        category: 'Personal',
        priority: 'low',
        dueDate: today,
        dueTime: '07:00',
        recurrence: 'daily',
      ),
      TaskItem(
        id: uid(),
        title: 'Book flights to Cebu',
        notes: 'Compare 5 affordable hotels too',
        category: 'Travel',
        priority: 'medium',
        dueDate: today.add(const Duration(days: 3)),
        dueTime: '12:00',
      ),
      TaskItem(
        id: uid(),
        title: 'Review investment portfolio',
        category: 'Finance',
        priority: 'medium',
        dueDate: today.add(const Duration(days: 5)),
      ),
      TaskItem(
        id: uid(),
        title: 'Pay rent',
        notes: 'Bank transfer to landlord',
        category: 'Finance',
        priority: 'high',
        kind: 'reminder',
        dueDate: _nextFirstOfMonth(),
        dueTime: '09:00',
        recurrence: 'monthly',
      ),
      TaskItem(
        id: uid(),
        title: 'Dentist appointment',
        category: 'Personal',
        priority: 'medium',
        kind: 'reminder',
        dueDate: today.add(const Duration(days: 2)),
        dueTime: '14:00',
      ),
    ];

    events = [
      CalEvent(
        id: uid(),
        title: 'Team standup',
        start: DateTime(tmr.year, tmr.month, tmr.day, 9, 0),
        end: DateTime(tmr.year, tmr.month, tmr.day, 9, 30),
        recurrence: 'weekly',
      ),
      CalEvent(
        id: uid(),
        title: 'Dinner with Langis',
        notes: 'Try that new restaurant in BGC',
        start: DateTime(today.year, today.month, today.day, 19, 0)
            .add(const Duration(days: 4)),
        end: DateTime(today.year, today.month, today.day, 21, 0)
            .add(const Duration(days: 4)),
      ),
      CalEvent(
        id: uid(),
        title: 'Flight to Cebu',
        start: DateTime(today.year, today.month, today.day, 8, 15)
            .add(const Duration(days: 12)),
        end: DateTime(today.year, today.month, today.day, 9, 45)
            .add(const Duration(days: 12)),
      ),
    ];

    activities = [
      ActivityItem(
          id: uid(),
          text: 'Reminder set: Pay rent · Monthly · 1st day',
          icon: 'alarm',
          ts: now.subtract(const Duration(hours: 5))),
      ActivityItem(
          id: uid(),
          text: 'Task completed: Send invoices',
          icon: 'check',
          ts: now.subtract(const Duration(days: 1, hours: 2))),
      ActivityItem(
          id: uid(),
          text: 'Summary generated: Q3 notes',
          icon: 'summarize',
          ts: now.subtract(const Duration(days: 2))),
    ];

    messages = [
      ChatMsg(
        id: uid(),
        role: 'assistant',
        text:
            'Hi $userName! I\'m Tasky, your virtual assistant. Tell me what you need — I can set reminders, draft emails, plan your day, summarize text, and more. Try: "Remind me to pay rent on the 1st every month."',
      ),
    ];
  }

  // ---------- helpers ----------

  void addActivity(String text, {String icon = 'sparkles'}) {
    activities.insert(
        0, ActivityItem(id: uid(), text: text, icon: icon));
    if (activities.length > 100) {
      activities = activities.sublist(0, 100);
    }
  }

  List<TaskItem> get activeTasks =>
      tasks.where((t) => !t.completed && t.kind == 'task').toList();

  List<TaskItem> tasksForDay(DateTime day) =>
      tasks.where((t) => !t.completed && t.occursOn(day)).toList();

  List<TaskItem> get todaysTasks {
    final list = tasksForDay(DateTime.now());
    list.sort((a, b) => _priorityRank(b).compareTo(_priorityRank(a)));
    return list;
  }

  List<TaskItem> get upcomingReminders {
    final now = DateTime.now();
    final list = tasks
        .where((t) =>
            !t.completed &&
            t.isReminder &&
            t.dueDate != null &&
            !dateOnly(t.dueDate!).isBefore(dateOnly(now)))
        .toList();
    list.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    return list;
  }

  List<TaskItem> get overdueTasks {
    final today = dateOnly(DateTime.now());
    return tasks
        .where((t) =>
            !t.completed &&
            t.dueDate != null &&
            dateOnly(t.dueDate!).isBefore(today) &&
            t.recurrence == 'none')
        .toList();
  }

  int _priorityRank(TaskItem t) =>
      t.priority == 'high' ? 3 : t.priority == 'medium' ? 2 : 1;

  List<CalEvent> eventsForDay(DateTime day) =>
      events.where((e) => e.occursOn(day)).toList();

  // ---------- mutations ----------

  Future<void> addTask(TaskItem t) async {
    tasks.add(t);
    await persist();
  }

  Future<void> updateTask(TaskItem t) async {
    final i = tasks.indexWhere((e) => e.id == t.id);
    if (i >= 0) tasks[i] = t;
    await persist();
  }

  Future<void> deleteTask(String id) async {
    tasks.removeWhere((e) => e.id == id);
    await persist();
  }

  Future<void> toggleComplete(TaskItem t) async {
    t.completed = !t.completed;
    if (t.completed) addActivity('Task completed: ${t.title}', icon: 'check');
    await persist();
  }

  Future<void> addEvent(CalEvent e) async {
    events.add(e);
    await persist();
  }

  Future<void> updateEvent(CalEvent e) async {
    final i = events.indexWhere((x) => x.id == e.id);
    if (i >= 0) events[i] = e;
    await persist();
  }

  Future<void> deleteEvent(String id) async {
    events.removeWhere((e) => e.id == id);
    await persist();
  }

  Future<void> addMessage(ChatMsg m) async {
    messages.add(m);
    await persist();
  }

  Future<void> resolveCard(ChatMsg m) async {
    m.cardResolved = true;
    await persist();
  }

  Future<void> clearChat() async {
    messages.clear();
    await persist();
  }

  /// Wipes all local data and restores the first-run demo content.
  Future<void> resetDemoData() async {
    tasks = [];
    events = [];
    messages = [];
    activities = [];
    _seedSampleData();
    await persist();
  }
}
