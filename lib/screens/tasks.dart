import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../nav.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class TasksScreen extends StatefulWidget {
  final TaskyNav nav;
  const TasksScreen({super.key, required this.nav});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _filter = 'All';
  bool _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskyStore>();
    var items = store.tasks.where((t) {
      if (!_showCompleted && t.completed) return false;
      if (_filter != 'All' && t.category != _filter) return false;
      return true;
    }).toList();
    items.sort((a, b) {
      if (a.completed != b.completed) return a.completed ? 1 : -1;
      final ad = a.dueDate;
      final bd = b.dueDate;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            tooltip: _showCompleted ? 'Hide completed' : 'Show completed',
            icon: Icon(_showCompleted
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined),
            onPressed: () =>
                setState(() => _showCompleted = !_showCompleted),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip('All'),
                ...taskCategories.map(_chip),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: const [
                      EmptyState(
                        icon: Icons.check_circle_outline,
                        title: 'All clear',
                        subtitle:
                            'No tasks here. Tap + to create one, or ask Tasky.',
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _taskTile(context, store, items[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(context, store, null),
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
    );
  }

  Widget _chip(String label) {
    final selected = _filter == label;
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: t.colorScheme.primary,
        labelStyle: TextStyle(
          color: selected
              ? Colors.white
              : (t.brightness == Brightness.dark
                  ? TaskyColors.inkDark
                  : TaskyColors.ink),
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => setState(() => _filter = label),
      ),
    );
  }

  Widget _taskTile(BuildContext context, TaskyStore store, TaskItem it) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TaskyCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: it.completed,
              onChanged: (_) => store.toggleComplete(it),
            ),
            Expanded(
              child: InkWell(
                onTap: () => _openSheet(context, store, it),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (it.isReminder)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.alarm,
                                  size: 16, color: TaskyColors.amber),
                            ),
                          Expanded(
                            child: Text(
                              it.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                decoration: it.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (it.notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(it.notes,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: t.brightness == Brightness.dark
                                      ? TaskyColors.inkSoftDark
                                      : TaskyColors.inkSoft)),
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _miniChip(it.category),
                          _miniChip(priorityLabel(it.priority),
                              dot: priorityColor(it.priority)),
                          if (it.dueDate != null)
                            _miniChip(
                                '${fmtDate(it.dueDate)}${it.dueTime != null ? ' · ${fmtTime(it.dueTime)}' : ''}',
                                icon: Icons.event),
                          if (it.recurrence != 'none')
                            _miniChip(it.recurrenceLabel(),
                                icon: Icons.repeat),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  _openSheet(context, store, it);
                } else if (v == 'delete') {
                  final ok = await confirmDialog(
                    context,
                    title: 'Delete "${it.title}"?',
                    message:
                        'This will permanently remove it. This can\'t be undone.',
                  );
                  if (ok) {
                    await store.deleteTask(it.id);
                    store.addActivity('Deleted: ${it.title}', icon: 'delete');
                    await store.persist();
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(String label, {Color? dot, IconData? icon}) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: t.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null)
            Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 5),
                decoration:
                    BoxDecoration(color: dot, shape: BoxShape.circle)),
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(icon, size: 12, color: t.colorScheme.primary),
            ),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: t.colorScheme.primary)),
        ],
      ),
    );
  }

  void _openSheet(BuildContext context, TaskyStore store, TaskItem? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TaskEditSheet(existing: existing),
    );
  }
}

class TaskEditSheet extends StatefulWidget {
  final TaskItem? existing;
  const TaskEditSheet({super.key, this.existing});

  @override
  State<TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends State<TaskEditSheet> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  String _category = 'Personal';
  String _priority = 'medium';
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  String _recurrence = 'none';
  bool _isReminder = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _notes.text = e.notes;
      _category = e.category;
      _priority = e.priority;
      _dueDate = e.dueDate;
      if (e.dueTime != null) {
        final p = e.dueTime!.split(':');
        _dueTime = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
      }
      _recurrence = e.recurrence;
      _isReminder = e.isReminder;
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            Text(widget.existing == null ? 'New task' : 'Edit task',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            // Task / Reminder toggle
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    label: Text('Task'),
                    icon: Icon(Icons.check_circle_outline)),
                ButtonSegment(
                    value: true,
                    label: Text('Reminder'),
                    icon: Icon(Icons.alarm)),
              ],
              selected: {_isReminder},
              onSelectionChanged: (s) =>
                  setState(() => _isReminder = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  const InputDecoration(hintText: 'Title', labelText: 'Title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                  hintText: 'Notes (optional)', labelText: 'Notes'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: taskCategories
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _category = v ?? 'Personal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _recurrence,
                    decoration: const InputDecoration(labelText: 'Repeats'),
                    items: const [
                      DropdownMenuItem(
                          value: 'none', child: Text('Never')),
                      DropdownMenuItem(
                          value: 'daily', child: Text('Daily')),
                      DropdownMenuItem(
                          value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(
                          value: 'monthly', child: Text('Monthly')),
                    ],
                    onChanged: (v) =>
                        setState(() => _recurrence = v ?? 'none'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Priority',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'low', label: Text('Low')),
                ButtonSegment(value: 'medium', label: Text('Medium')),
                ButtonSegment(value: 'high', label: Text('High')),
              ],
              selected: {_priority},
              onSelectionChanged: (s) =>
                  setState(() => _priority = s.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(_dueDate == null
                        ? 'Due date'
                        : fmtDate(_dueDate)),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? DateTime.now(),
                        firstDate: DateTime.now()
                            .subtract(const Duration(days: 365)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 3)),
                      );
                      if (d != null) setState(() => _dueDate = d);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(_dueTime == null
                        ? 'Time'
                        : _dueTime!.format(context)),
                    onPressed: () async {
                      final tod = await showTimePicker(
                        context: context,
                        initialTime:
                            _dueTime ?? const TimeOfDay(hour: 9, minute: 0),
                      );
                      if (tod != null) setState(() => _dueTime = tod);
                    },
                  ),
                ),
                if (_dueDate != null || _dueTime != null)
                  IconButton(
                    tooltip: 'Clear date/time',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _dueDate = null;
                      _dueTime = null;
                    }),
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
                            content:
                                Text('Give it a title first.')));
                    return;
                  }
                  final item = TaskItem(
                    id: widget.existing?.id ?? uid(),
                    title: title,
                    notes: _notes.text.trim(),
                    category: _category,
                    priority: _priority,
                    dueDate: _dueDate == null
                        ? null
                        : dateOnly(_dueDate!),
                    dueTime: _dueTime == null
                        ? null
                        : '${_dueTime!.hour.toString().padLeft(2, '0')}:${_dueTime!.minute.toString().padLeft(2, '0')}',
                    recurrence: _recurrence,
                    completed: widget.existing?.completed ?? false,
                    createdAt: widget.existing?.createdAt,
                    kind: _isReminder ? 'reminder' : 'task',
                  );
                  if (widget.existing == null) {
                    await store.addTask(item);
                    store.addActivity(
                        '${_isReminder ? 'Reminder' : 'Task'} created: $title',
                        icon: _isReminder ? 'alarm' : 'sparkles');
                  } else {
                    await store.updateTask(item);
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
