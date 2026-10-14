import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../nav.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class HomeScreen extends StatefulWidget {
  final TaskyNav nav;
  const HomeScreen({super.key, required this.nav});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _input = TextEditingController();
  final _speech = SpeechToText();
  bool _listening = false;
  bool _speechReady = false;

  @override
  void dispose() {
    _input.dispose();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    if (!_speechReady) {
      _speechReady = await _speech.initialize();
    }
    if (!_speechReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Voice input isn\'t available on this device.')));
      }
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) {
        _input.text = r.recognizedWords;
        _input.selection = TextSelection.fromPosition(
            TextPosition(offset: _input.text.length));
      },
    );
    // auto-stop when done
    _speech.statusListener = (s) {
      if ((s == 'done' || s == 'notListening') && mounted) {
        setState(() => _listening = false);
      }
    };
  }

  void _submit() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    widget.nav.askAssistant(text);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskyStore>();
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            const SizedBox(height: 8),
            Text('${dayGreeting()}, ${store.userName}',
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text('What can I help you with?',
                style: TextStyle(
                    fontSize: 16,
                    color: t.brightness == Brightness.dark
                        ? TaskyColors.inkSoftDark
                        : TaskyColors.inkSoft)),
            const SizedBox(height: 18),
            // Large AI input box
            Container(
              decoration: taskyCardDeco(context),
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
              child: Column(
                children: [
                  TextField(
                    controller: _input,
                    maxLines: 3,
                    minLines: 2,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submit(),
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'Ask Tasky anything…',
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Voice input',
                        onPressed: _toggleMic,
                        icon: Icon(
                          _listening ? Icons.mic : Icons.mic_none,
                          color: _listening
                              ? t.colorScheme.error
                              : t.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Ask'),
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Quick actions
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.25,
              children: [
                _quickAction(context, Icons.edit_note, 'Write',
                    () => widget.nav.openTool('write')),
                _quickAction(context, Icons.search, 'Research',
                    () => widget.nav.openTool('research')),
                _quickAction(context, Icons.map_outlined, 'Plan',
                    () => widget.nav.openTool('plan')),
                _quickAction(context, Icons.table_chart_outlined, 'Organize',
                    () => widget.nav.askAssistant('Organize this into a table: ')),
                _quickAction(context, Icons.alarm, 'Remind Me',
                    () => widget.nav.askAssistant('Remind me to ')),
                _quickAction(context, Icons.summarize_outlined, 'Summarize',
                    () => widget.nav.openTool('summarize')),
              ],
            ),
            SectionHeader(
                title: "Today's tasks",
                actionLabel: 'See all',
                onAction: () => widget.nav.goTab(1)),
            ..._todayList(context, store),
            SectionHeader(title: 'Upcoming reminders'),
            ..._remindersList(context, store),
            SectionHeader(title: 'Recent activity'),
            ..._activityList(context, store),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final t = Theme.of(context);
    return TaskyCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: t.colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: t.colorScheme.primary, size: 22),
          ),
          const SizedBox(height: 7),
          Text(label,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  List<Widget> _todayList(BuildContext context, TaskyStore store) {
    final items = store.todaysTasks.take(5).toList();
    if (items.isEmpty) {
      return [
        const TaskyCard(
            child: Text('Nothing due today. Enjoy the calm — or ask Tasky to plan something.'))
      ];
    }
    return items
        .map((it) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TaskyCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                onTap: () => widget.nav.goTab(1),
                child: Row(
                  children: [
                    Checkbox(
                      value: it.completed,
                      onChanged: (_) {
                        store.toggleComplete(it);
                        _reschedule(context, store);
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it.title,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                              '${it.category} · ${it.dueTime != null ? fmtTime(it.dueTime) : 'No time'}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? TaskyColors.inkSoftDark
                                      : TaskyColors.inkSoft)),
                        ],
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: priorityColor(it.priority),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ))
        .toList();
  }

  List<Widget> _remindersList(BuildContext context, TaskyStore store) {
    final items = store.upcomingReminders.take(3).toList();
    if (items.isEmpty) {
      return [
        const TaskyCard(
            child: Text('No upcoming reminders. Say "Remind me to…" and Tasky will handle it.'))
      ];
    }
    final t = Theme.of(context);
    return items
        .map((it) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TaskyCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: TaskyColors.amber.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.alarm,
                          color: TaskyColors.amber, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it.title,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          Text(
                              '${fmtDate(it.dueDate)} · ${fmtTime(it.dueTime)} · ${it.recurrenceLabel()}',
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
            ))
        .toList();
  }

  List<Widget> _activityList(BuildContext context, TaskyStore store) {
    final items = store.activities.take(4).toList();
    if (items.isEmpty) {
      return [const TaskyCard(child: Text('No activity yet.'))];
    }
    return items
        .map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(_activityIcon(a.icon),
                      size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(a.text,
                          style: const TextStyle(fontSize: 14))),
                ],
              ),
            ))
        .toList();
  }

  IconData _activityIcon(String name) {
    switch (name) {
      case 'alarm':
        return Icons.alarm;
      case 'check':
        return Icons.check_circle;
      case 'summarize':
        return Icons.summarize;
      case 'mail':
        return Icons.mail;
      case 'delete':
        return Icons.delete;
      default:
        return Icons.auto_awesome;
    }
  }

  void _reschedule(BuildContext context, TaskyStore store) {
    // notifications rescheduled by the shell listener; no-op here
  }
}
