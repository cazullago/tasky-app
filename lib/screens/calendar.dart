import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../nav.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class CalendarScreen extends StatefulWidget {
  final TaskyNav nav;
  const CalendarScreen({super.key, required this.nav});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selected = dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskyStore>();
    final t = Theme.of(context);
    final dayItems = store.tasksForDay(_selected);
    final dayEvents = store.eventsForDay(_selected);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          TaskyCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setState(() => _month =
                          DateTime(_month.year, _month.month - 1, 1)),
                    ),
                    Text(_monthLabel(_month),
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setState(() => _month =
                          DateTime(_month.year, _month.month + 1, 1)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _weekdayHeader(t),
                _monthGrid(context, store),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => setState(() {
                    final now = DateTime.now();
                    _month = DateTime(now.year, now.month, 1);
                    _selected = dateOnly(now);
                  }),
                  child: const Text('Today'),
                ),
              ],
            ),
          ),
          SectionHeader(title: _dayLabel(_selected)),
          if (dayItems.isEmpty && dayEvents.isEmpty)
            const TaskyCard(
                child: Text('Nothing scheduled this day. Tap + to add an event.')),
          ...dayItems.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TaskyCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Checkbox(
                          value: it.completed,
                          onChanged: (_) => store.toggleComplete(it)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (it.isReminder)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(Icons.alarm,
                                        size: 15, color: TaskyColors.amber),
                                  ),
                                Expanded(
                                  child: Text(it.title,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          decoration: it.completed
                                              ? TextDecoration.lineThrough
                                              : null)),
                                ),
                              ],
                            ),
                            Text(
                                '${it.category}${it.dueTime != null ? ' · ${fmtTime(it.dueTime)}' : ''}${it.recurrence != 'none' ? ' · ${it.recurrenceLabel()}' : ''}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: t.brightness == Brightness.dark
                                        ? TaskyColors.inkSoftDark
                                        : TaskyColors.inkSoft)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
          ...dayEvents.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TaskyCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  onTap: () => _openEventSheet(context, store, e),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            Text(
                                e.allDay
                                    ? 'All day${e.recurrence != 'none' ? ' · ${e.recurrence}' : ''}'
                                    : '${_hm(e.start)} – ${_hm(e.end)}${e.recurrence != 'none' ? ' · ${e.recurrence}' : ''}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: t.brightness == Brightness.dark
                                        ? TaskyColors.inkSoftDark
                                        : TaskyColors.inkSoft)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () async {
                          final ok = await confirmDialog(context,
                              title: 'Delete "${e.title}"?',
                              message: 'This event will be removed.');
                          if (ok) await store.deleteEvent(e.id);
                        },
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEventSheet(context, store, null),
        icon: const Icon(Icons.add),
        label: const Text('New event'),
      ),
    );
  }

  String _monthLabel(DateTime m) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[m.month - 1]} ${m.year}';
  }

  String _dayLabel(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.month}/${d.day}';
  }

  Widget _weekdayHeader(ThemeData t) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: days
          .map((d) => Expanded(
                  child: Center(
                      child: Text(d,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: t.brightness == Brightness.dark
                                  ? TaskyColors.inkSoftDark
                                  : TaskyColors.inkSoft)))))
          .toList(),
    );
  }

  Widget _monthGrid(BuildContext context, TaskyStore store) {
    final t = Theme.of(context);
    final first = _month;
    final startOffset = (first.weekday - 1) % 7; // Monday-first
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final today = dateOnly(DateTime.now());
    final cells = <Widget>[];
    for (var i = 0; i < startOffset; i++) {
      cells.add(const SizedBox(height: 44));
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(first.year, first.month, d);
      final hasTasks =
          store.tasks.any((x) => !x.completed && x.occursOn(date));
      final hasReminders = store.tasks
          .any((x) => !x.completed && x.isReminder && x.occursOn(date));
      final hasEvents = store.events.any((e) => e.occursOn(date));
      final isSel = date == _selected;
      final isToday = date == today;
      cells.add(
        GestureDetector(
          onTap: () => setState(() => _selected = date),
          child: Container(
            height: 44,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSel ? t.colorScheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isToday && !isSel
                  ? Border.all(color: t.colorScheme.primary, width: 1.4)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$d',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSel ? FontWeight.w800 : FontWeight.w500,
                        color: isSel
                            ? Colors.white
                            : (t.brightness == Brightness.dark
                                ? TaskyColors.inkDark
                                : TaskyColors.ink))),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (hasTasks)
                      _dot(isSel
                          ? Colors.white
                          : t.colorScheme.primary),
                    if (hasReminders)
                      _dot(isSel ? Colors.white : TaskyColors.amber),
                    if (hasEvents)
                      _dot(isSel ? Colors.white : Colors.blueAccent),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cells,
    );
  }

  Widget _dot(Color c) => Container(
        width: 5,
        height: 5,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  String _hm(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  void _openEventSheet(
      BuildContext context, TaskyStore store, CalEvent? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => EventEditSheet(existing: existing, initialDay: _selected),
    );
  }
}

class EventEditSheet extends StatefulWidget {
  final CalEvent? existing;
  final DateTime initialDay;
  const EventEditSheet(
      {super.key, this.existing, required this.initialDay});

  @override
  State<EventEditSheet> createState() => _EventEditSheetState();
}

class _EventEditSheetState extends State<EventEditSheet> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  late DateTime _date;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  bool _allDay = false;
  String _recurrence = 'none';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e == null ? widget.initialDay : dateOnly(e.start);
    if (e != null) {
      _title.text = e.title;
      _notes.text = e.notes;
      _start = TimeOfDay(hour: e.start.hour, minute: e.start.minute);
      _end = TimeOfDay(hour: e.end.hour, minute: e.end.minute);
      _allDay = e.allDay;
      _recurrence = e.recurrence;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<TaskyStore>();
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 12),
            Text(widget.existing == null ? 'New event' : 'Edit event',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(
                controller: _title,
                autofocus: widget.existing == null,
                decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 10),
            TextField(
                controller: _notes,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Notes (optional)')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(fmtDate(_date)),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime.now()
                            .subtract(const Duration(days: 365)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 3)),
                      );
                      if (d != null) setState(() => _date = d);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _recurrence,
                    decoration: const InputDecoration(labelText: 'Repeats'),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('Never')),
                      DropdownMenuItem(value: 'daily', child: Text('Daily')),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    ],
                    onChanged: (v) =>
                        setState(() => _recurrence = v ?? 'none'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('All day'),
              value: _allDay,
              onChanged: (v) => setState(() => _allDay = v),
            ),
            if (!_allDay)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final tod = await showTimePicker(
                            context: context, initialTime: _start);
                        if (tod != null) setState(() => _start = tod);
                      },
                      child: Text('Starts ${_start.format(context)}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final tod = await showTimePicker(
                            context: context, initialTime: _end);
                        if (tod != null) setState(() => _end = tod);
                      },
                      child: Text('Ends ${_end.format(context)}'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final title = _title.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Give it a title first.')));
                    return;
                  }
                  final start = DateTime(_date.year, _date.month, _date.day,
                      _allDay ? 0 : _start.hour, _allDay ? 0 : _start.minute);
                  var end = DateTime(_date.year, _date.month, _date.day,
                      _allDay ? 23 : _end.hour, _allDay ? 59 : _end.minute);
                  if (end.isBefore(start)) {
                    end = start.add(const Duration(hours: 1));
                  }
                  final ev = CalEvent(
                    id: widget.existing?.id ?? uid(),
                    title: title,
                    notes: _notes.text.trim(),
                    start: start,
                    end: end,
                    allDay: _allDay,
                    recurrence: _recurrence,
                  );
                  if (widget.existing == null) {
                    await store.addEvent(ev);
                    store.addActivity('Event created: $title', icon: 'sparkles');
                  } else {
                    await store.updateEvent(ev);
                  }
                  await store.persist();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Text(widget.existing == null ? 'Create' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
