import 'dart:math';

final _rand = Random();

String uid() =>
    '${DateTime.now().microsecondsSinceEpoch}${_rand.nextInt(1 << 32)}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// A task or a reminder. Reminders are tasks with kind == 'reminder'.
class TaskItem {
  final String id;
  String title;
  String notes;
  String category; // Personal, Work, Business, Shopping, Travel, Finance, Other
  String priority; // low | medium | high
  DateTime? dueDate; // date-only
  String? dueTime; // 'HH:mm' 24h
  String recurrence; // none | daily | weekly | monthly
  bool completed;
  final DateTime createdAt;
  String kind; // 'task' | 'reminder'

  TaskItem({
    required this.id,
    required this.title,
    this.notes = '',
    this.category = 'Personal',
    this.priority = 'medium',
    this.dueDate,
    this.dueTime,
    this.recurrence = 'none',
    this.completed = false,
    DateTime? createdAt,
    this.kind = 'task',
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isReminder => kind == 'reminder';

  String recurrenceLabel() {
    switch (recurrence) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        if (dueDate != null) {
          final d = dueDate!.day;
          final suffix = d == 1
              ? 'st'
              : d == 2
                  ? 'nd'
                  : d == 3
                      ? 'rd'
                      : 'th';
          return 'Monthly · $d$suffix day';
        }
        return 'Monthly';
      default:
        return 'One-time';
    }
  }

  /// True when this item occurs on [day] (recurrence-aware).
  bool occursOn(DateTime day) {
    final d = dateOnly(day);
    final start = dueDate == null ? null : dateOnly(dueDate!);
    if (start == null) return false;
    if (d.isBefore(start)) return false;
    switch (recurrence) {
      case 'none':
        return d == start;
      case 'daily':
        return true;
      case 'weekly':
        return d.weekday == start.weekday;
      case 'monthly':
        final dim = DateTime(d.year, d.month + 1, 0).day;
        final target = start.day > dim ? dim : start.day;
        return d.day == target;
      default:
        return d == start;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'category': category,
        'priority': priority,
        'dueDate': dueDate?.toIso8601String(),
        'dueTime': dueTime,
        'recurrence': recurrence,
        'completed': completed,
        'createdAt': createdAt.toIso8601String(),
        'kind': kind,
      };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        category: j['category'] as String? ?? 'Personal',
        priority: j['priority'] as String? ?? 'medium',
        dueDate: j['dueDate'] == null
            ? null
            : dateOnly(DateTime.parse(j['dueDate'] as String)),
        dueTime: j['dueTime'] as String?,
        recurrence: j['recurrence'] as String? ?? 'none',
        completed: j['completed'] as bool? ?? false,
        createdAt: j['createdAt'] == null
            ? DateTime.now()
            : DateTime.parse(j['createdAt'] as String),
        kind: j['kind'] as String? ?? 'task',
      );
}

class CalEvent {
  final String id;
  String title;
  String notes;
  DateTime start;
  DateTime end;
  bool allDay;
  String recurrence; // none | daily | weekly | monthly

  CalEvent({
    required this.id,
    required this.title,
    this.notes = '',
    required this.start,
    required this.end,
    this.allDay = false,
    this.recurrence = 'none',
  });

  bool occursOn(DateTime day) {
    final d = dateOnly(day);
    final s = dateOnly(start);
    if (d.isBefore(s)) return false;
    switch (recurrence) {
      case 'none':
        return d == s;
      case 'daily':
        return true;
      case 'weekly':
        return d.weekday == s.weekday;
      case 'monthly':
        final dim = DateTime(d.year, d.month + 1, 0).day;
        final target = s.day > dim ? dim : s.day;
        return d.day == target;
      default:
        return d == s;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'allDay': allDay,
        'recurrence': recurrence,
      };

  factory CalEvent.fromJson(Map<String, dynamic> j) => CalEvent(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        start: DateTime.parse(j['start'] as String),
        end: DateTime.parse(j['end'] as String),
        allDay: j['allDay'] as bool? ?? false,
        recurrence: j['recurrence'] as String? ?? 'none',
      );
}

/// Action card attached to an assistant message. Nothing is executed until
/// the user taps the confirm button.
class ActionCard {
  final String kind; // reminder | task | email | delete | info
  final String title;
  final List<String> lines;
  final String confirmLabel;
  final String? secondaryLabel;
  final Map<String, dynamic> payload;

  ActionCard({
    required this.kind,
    required this.title,
    required this.lines,
    required this.confirmLabel,
    this.secondaryLabel,
    Map<String, dynamic>? payload,
  }) : payload = payload ?? {};

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'title': title,
        'lines': lines,
        'confirmLabel': confirmLabel,
        'secondaryLabel': secondaryLabel,
        'payload': payload,
      };

  factory ActionCard.fromJson(Map<String, dynamic> j) => ActionCard(
        kind: j['kind'] as String,
        title: j['title'] as String,
        lines: (j['lines'] as List).map((e) => e.toString()).toList(),
        confirmLabel: j['confirmLabel'] as String,
        secondaryLabel: j['secondaryLabel'] as String?,
        payload: Map<String, dynamic>.from(j['payload'] as Map? ?? {}),
      );
}

class ChatMsg {
  final String id;
  final String role; // user | assistant
  String text;
  final DateTime ts;
  ActionCard? card;
  bool cardResolved;

  ChatMsg({
    required this.id,
    required this.role,
    required this.text,
    DateTime? ts,
    this.card,
    this.cardResolved = false,
  }) : ts = ts ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'text': text,
        'ts': ts.toIso8601String(),
        'card': card?.toJson(),
        'cardResolved': cardResolved,
      };

  factory ChatMsg.fromJson(Map<String, dynamic> j) => ChatMsg(
        id: j['id'] as String,
        role: j['role'] as String,
        text: j['text'] as String? ?? '',
        ts: DateTime.parse(j['ts'] as String),
        card: j['card'] == null
            ? null
            : ActionCard.fromJson(Map<String, dynamic>.from(j['card'] as Map)),
        cardResolved: j['cardResolved'] as bool? ?? false,
      );
}

class ActivityItem {
  final String id;
  final String text;
  final DateTime ts;
  final String icon; // material icon name key

  ActivityItem({
    required this.id,
    required this.text,
    DateTime? ts,
    this.icon = 'sparkles',
  }) : ts = ts ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'ts': ts.toIso8601String(),
        'icon': icon,
      };

  factory ActivityItem.fromJson(Map<String, dynamic> j) => ActivityItem(
        id: j['id'] as String,
        text: j['text'] as String? ?? '',
        ts: DateTime.parse(j['ts'] as String),
        icon: j['icon'] as String? ?? 'sparkles',
      );
}

const List<String> taskCategories = [
  'Personal',
  'Work',
  'Business',
  'Shopping',
  'Travel',
  'Finance',
  'Other',
];

const List<String> priorities = ['low', 'medium', 'high'];

const List<String> recurrences = ['none', 'daily', 'weekly', 'monthly'];
