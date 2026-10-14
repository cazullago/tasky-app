import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../ai.dart';
import '../models.dart';
import '../nav.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class AssistantScreen extends StatefulWidget {
  final TaskyNav nav;
  const AssistantScreen({super.key, required this.nav});

  @override
  State<AssistantScreen> createState() => AssistantScreenState();
}

class AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _speech = SpeechToText();
  bool _listening = false;
  bool _speechReady = false;
  bool _thinking = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _speech.cancel();
    super.dispose();
  }

  /// Called by the shell when a quick action prefills a prompt.
  void prefill(String text) {
    _input.text = text;
    _input.selection =
        TextSelection.fromPosition(TextPosition(offset: text.length));
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
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
    await _speech.listen(onResult: (r) {
      _input.text = r.recognizedWords;
      _input.selection = TextSelection.fromPosition(
          TextPosition(offset: _input.text.length));
    });
    _speech.statusListener = (s) {
      if ((s == 'done' || s == 'notListening') && mounted) {
        setState(() => _listening = false);
      }
    };
  }

  Future<void> _send([String? override]) async {
    final text = (override ?? _input.text).trim();
    if (text.isEmpty || _thinking) return;
    final store = context.read<TaskyStore>();
    _input.clear();
    await store.addMessage(ChatMsg(id: uid(), role: 'user', text: text));
    setState(() => _thinking = true);
    _scrollDown();
    try {
      final provider = buildProvider(
        providerId: store.aiProvider,
        apiKey: store.apiKey,
        baseUrl: store.baseUrl,
        model: store.model,
        tone: store.aiTone,
      );
      final reply = await provider.generate(
          text, AiContext(userName: store.userName, tasks: store.tasks));
      await store.addMessage(ChatMsg(
          id: uid(), role: 'assistant', text: reply.text, card: reply.card));
      if (reply.needsApiKey) {
        store.addActivity('Assistant: AI key needed', icon: 'sparkles');
        await store.persist();
      }
    } catch (_) {
      await store.addMessage(ChatMsg(
          id: uid(),
          role: 'assistant',
          text: 'Something went wrong on my end — please try again.'));
    }
    if (mounted) setState(() => _thinking = false);
    _scrollDown();
  }

  /// Executes ONLY after the user tapped the card's confirm button.
  Future<void> _confirmCard(ChatMsg msg, ActionCard card) async {
    final store = context.read<TaskyStore>();
    switch (card.kind) {
      case 'reminder':
        final p = card.payload;
        final item = TaskItem(
          id: uid(),
          title: p['title'] as String? ?? card.title,
          kind: 'reminder',
          category: 'Personal',
          priority: 'medium',
          dueDate: p['date'] == null
              ? null
              : dateOnly(DateTime.parse(p['date'] as String)),
          dueTime: p['time'] as String?,
          recurrence: p['recurrence'] as String? ?? 'none',
        );
        await store.addTask(item);
        store.addActivity(
            'Reminder set: ${item.title} · ${item.recurrenceLabel()}',
            icon: 'alarm');
        await store.persist();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reminder confirmed.')));
        }
        break;
      case 'task':
        final title =
            (card.payload['title'] as String?) ?? card.title;
        final item = TaskItem(id: uid(), title: title);
        await store.addTask(item);
        store.addActivity('Task created: $title', icon: 'sparkles');
        await store.persist();
        break;
      case 'email':
        // v1 has no email integration — be honest about it.
        store.addActivity('Email draft prepared (demo — not sent)',
            icon: 'mail');
        await store.persist();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Demo mode: draft prepared, not sent. Email integration coming in a later version.')));
        }
        break;
      case 'delete':
        final id = card.payload['id'] as String?;
        if (id != null) {
          final t =
              store.tasks.where((e) => e.id == id).firstOrNull;
          await store.deleteTask(id);
          store.addActivity('Deleted: ${t?.title ?? 'item'}',
              icon: 'delete');
          await store.persist();
        }
        break;
      default:
        break;
    }
    await store.resolveCard(msg);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskyStore>();
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: t.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Assistant'),
          ],
        ),
        actions: [
          ProviderBadge(
              text: store.aiProvider == 'http' ? 'Live API' : 'Demo mode',
              live: store.aiProvider == 'http'),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Clear chat',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              final ok = await confirmDialog(context,
                  title: 'Clear chat?',
                  message: 'This removes the conversation history.',
                  confirmLabel: 'Clear');
              if (ok) await store.clearChat();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              itemCount: store.messages.length + (_thinking ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= store.messages.length) {
                  return _bubble(
                      context, true, 'Thinking…', null, null, true);
                }
                final m = store.messages[i];
                return _bubble(context, m.role == 'assistant', m.text,
                    m.card, m, false);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: t.cardColor,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -4)),
                ],
              ),
              child: Row(
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
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Message Tasky…',
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: t.colorScheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      tooltip: 'Send',
                      onPressed: () => _send(),
                      icon: const Icon(Icons.send,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context, bool isAssistant, String text,
      ActionCard? card, ChatMsg? msg, bool thinking) {
    final t = Theme.of(context);
    return Align(
      alignment:
          isAssistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isAssistant
              ? t.cardColor
              : t.colorScheme.primary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isAssistant ? 4 : 18),
            bottomRight: Radius.circular(isAssistant ? 18 : 4),
          ),
          boxShadow: isAssistant
              ? [
                  BoxShadow(
                      color: Colors.black.withOpacity(
                          t.brightness == Brightness.dark ? 0.3 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              thinking ? 'Thinking…' : text,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: isAssistant
                    ? (t.brightness == Brightness.dark
                        ? TaskyColors.inkDark
                        : TaskyColors.ink)
                    : Colors.white,
              ),
            ),
            if (card != null && msg != null && isAssistant)
              ActionCardView(
                card: card,
                resolved: msg.cardResolved,
                onConfirm: (c) => _confirmCard(msg, c),
                onSecondary: () async {
                  final store = context.read<TaskyStore>();
                  await store.resolveCard(msg);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Cancelled — nothing was changed.')));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
