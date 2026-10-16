import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../ai.dart';
import '../demo.dart';
import '../models.dart';
import '../notify.dart';
import '../perms.dart';
import '../store.dart';
import '../va_defs.dart';
import '../widgets/ui.dart';

/// Per-VA screen: tool grid, memory editor entry, and the catch-all
/// "Chat with my VA" panel at the bottom.
class VaScreen extends StatefulWidget {
  final String vaId;
  final String? initialToolId;

  const VaScreen({super.key, required this.vaId, this.initialToolId});

  @override
  State<VaScreen> createState() => _VaScreenState();
}

class _VaScreenState extends State<VaScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialToolId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openTool(widget.initialToolId!);
      });
    }
  }

  void _openTool(String toolId) {
    final va = VaDefs.get(widget.vaId);
    ToolDef? tool;
    for (final t in va.tools) {
      if (t.id == toolId) tool = t;
    }
    if (tool == null || !mounted) return;
    final t = tool;
    switch (t.kind) {
      case ToolKind.list:
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ListToolPage(vaId: va.id, tool: t)));
        break;
      case ToolKind.reminder:
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ReminderPage(vaId: va.id)));
        break;
      case ToolKind.timer:
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TimerPage(vaId: va.id)));
        break;
      case ToolKind.scan:
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ScanPage(vaId: va.id, tool: t)));
        break;
      case ToolKind.generator:
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ToolRunnerPage(vaId: va.id, tool: t)));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final va = VaDefs.get(widget.vaId);
    final store = context.watch<AppStore>();
    final profile = store.profileOf(va.id);
    final name = va.displayName(profile.customName);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            VaAvatar(va: va, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(va.subtitle(),
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "$name's memory",
            icon: const Text('🧠', style: TextStyle(fontSize: 22)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => MemoryPage(vaId: va.id)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            va.tagline,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7)),
          ),
          const SectionTitle(text: 'Tools'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
            ),
            itemCount: va.tools.length,
            itemBuilder: (context, i) {
              final tool = va.tools[i];
              return _ToolTile(
                  va: va,
                  tool: tool,
                  onTap: () => _openTool(tool.id));
            },
          ),
          SectionTitle(
            text: 'Chat with $name',
            actionLabel: 'Clear',
            onAction: () async {
              final ok = await confirmDialog(
                context,
                title: 'Clear chat?',
                body: 'This erases your conversation with $name on this device.',
                confirmLabel: 'Clear',
                destructive: true,
              );
              if (ok && context.mounted) {
                context.read<AppStore>().clearChat(va.id);
              }
            },
          ),
          _ChatPanel(vaId: va.id, onOpenTool: _openTool),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  final VaDef va;
  final ToolDef tool;
  final VoidCallback onTap;

  const _ToolTile({required this.va, required this.tool, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              va.colorA.withValues(alpha: 0.14),
              va.colorB.withValues(alpha: 0.07),
            ],
          ),
          border: Border.all(color: va.colorA.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tool.glyph, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 8),
            Text(tool.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(tool.blurb,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }
}

// =================================================================== chat
class _ChatPanel extends StatefulWidget {
  final String vaId;
  final void Function(String toolId) onOpenTool;

  const _ChatPanel({required this.vaId, required this.onOpenTool});

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;
  bool _useLiveAi = false;
  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;
  bool _listening = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    try {
      _speech.cancel();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    final store = context.read<AppStore>();
    final va = VaDefs.get(widget.vaId);
    final profile = store.profileOf(va.id);
    setState(() {
      _busy = true;
      _input.clear();
    });
    store.addChatMsg(ChatMsg(
      id: store.uuid.v4(),
      vaId: va.id,
      fromUser: true,
      text: text,
      time: DateTime.now(),
    ));
    _scrollToEnd();

    String replyText;
    String? toolId;
    try {
      if (_useLiveAi && store.ai.configured) {
        final mem = profile.fields.entries
            .map((e) => '${e.key}: ${e.value}')
            .join('\n');
        replyText = await AiService.complete(
          cfg: store.ai,
          system:
              '${va.systemPrompt}\n\nWhat you remember about the user:\n$mem\n\nKeep replies concise and warm.',
          user: text,
        );
      } else {
        final reply = DemoEngine.chat(va.id, text, {
          ...profile.fields,
          'customName': profile.customName,
        }, store);
        replyText = reply.text;
        toolId = reply.toolId;
      }
    } on AiException catch (e) {
      replyText =
          'The live AI hit a snag: ${e.message}\n\nI can keep helping in demo mode meanwhile.';
    } catch (e) {
      debugPrint('Tasky chat failed: $e');
      replyText = 'Hmm, that didn\'t go through. Try again?';
    }
    if (!mounted) return;
    store.addChatMsg(ChatMsg(
      id: store.uuid.v4(),
      vaId: va.id,
      fromUser: false,
      text: replyText,
      time: DateTime.now(),
      toolId: toolId,
    ));
    setState(() => _busy = false);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleMic() async {
    final store = context.read<AppStore>();
    if (!store.settings.voiceInput) {
      showSnack(context, 'Voice input is off (Profile → Settings).');
      return;
    }
    try {
      if (!_speechReady) {
        _speechReady = await _speech.initialize(onError: (_) {}, onStatus: (_) {});
      }
      if (!mounted) return;
      if (!_speechReady) {
        showSnack(context, 'Voice input isn\'t available on this device.');
        return;
      }
      if (_listening) {
        await _speech.stop();
        if (mounted) setState(() => _listening = false);
        return;
      }
      final ok = await PermissionService.ensureMicrophone(context);
      if (!ok || !mounted) return;
      setState(() => _listening = true);
      await _speech.listen(
        onResult: (r) {
          _input.text = r.recognizedWords;
          _input.selection = TextSelection.fromPosition(
              TextPosition(offset: _input.text.length));
        },
        listenOptions:
            SpeechListenOptions(listenFor: const Duration(seconds: 30)),
      );
    } catch (e) {
      debugPrint('Tasky chat mic failed: $e');
      if (mounted) setState(() => _listening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final va = VaDefs.get(widget.vaId);
    final profile = store.profileOf(va.id);
    final name = va.displayName(profile.customName);
    final messages = store.chatOf(va.id);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                VaAvatar(va: va, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Chat with $name',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                if (store.ai.configured)
                  GestureDetector(
                    onTap: () =>
                        setState(() => _useLiveAi = !_useLiveAi),
                    child: _useLiveAi
                        ? const LiveBadge()
                        : const DemoBadge(),
                  )
                else
                  const DemoBadge(),
              ],
            ),
            if (store.ai.configured) ...[
              const SizedBox(height: 6),
              Text(
                _useLiveAi
                    ? 'Live AI answers via your configured provider.'
                    : 'Tap the badge to switch to live AI answers.',
                style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.55)),
              ),
            ],
            const SizedBox(height: 10),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Say hello to $name!\nI\'ll point you to the right tool — or just chat.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: scheme.onSurface
                                  .withValues(alpha: 0.55)),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(10),
                      itemCount: messages.length,
                      itemBuilder: (context, i) =>
                          _ChatBubble(
                              msg: messages[i],
                              va: va,
                              onOpenTool: widget.onOpenTool),
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: InputDecoration(
                      hintText: 'Message $name…',
                      suffixIcon: IconButton(
                        tooltip: _listening ? 'Stop' : 'Dictate',
                        icon: Icon(
                          _listening ? Icons.mic : Icons.mic_none_outlined,
                          color: _listening ? Colors.red : null,
                        ),
                        onPressed: _toggleMic,
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _send,
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(14),
                    backgroundColor: va.colorA,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMsg msg;
  final VaDef va;
  final void Function(String toolId) onOpenTool;

  const _ChatBubble(
      {required this.msg, required this.va, required this.onOpenTool});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final align =
        msg.fromUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = msg.fromUser
        ? va.colorA
        : scheme.surfaceContainerHighest;
    final fg = msg.fromUser
        ? Colors.white
        : scheme.onSurface;
    ToolDef? tool;
    if (msg.toolId != null) {
      for (final t in va.tools) {
        if (t.id == msg.toolId) tool = t;
      }
    }
    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: msg.fromUser
                ? const Radius.circular(4)
                : const Radius.circular(18),
            bottomLeft: msg.fromUser
                ? const Radius.circular(18)
                : const Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.text, style: TextStyle(color: fg, fontSize: 14)),
            if (tool != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => onOpenTool(tool!.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tool.glyph,
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text('Open ${tool.title}',
                            style: TextStyle(
                                color: fg,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================ tool runner
class ToolRunnerPage extends StatefulWidget {
  final String vaId;
  final ToolDef tool;

  const ToolRunnerPage({super.key, required this.vaId, required this.tool});

  @override
  State<ToolRunnerPage> createState() => _ToolRunnerPageState();
}

class _ToolRunnerPageState extends State<ToolRunnerPage> {
  final _formKey = GlobalKey<ToolFormState>();
  bool _busy = false;
  bool _useLiveAi = false;
  String? _result;
  bool _resultWasLive = false;

  Future<void> _run() async {
    if (_busy) return;
    final store = context.read<AppStore>();
    final va = VaDefs.get(widget.vaId);
    final profile = store.profileOf(va.id);
    final inputs = _formKey.currentState?.values() ?? {};
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      if (_useLiveAi && store.ai.configured) {
        final mem = profile.fields.entries
            .map((e) => '${e.key}: ${e.value}')
            .join('\n');
        final inputText =
            inputs.entries.map((e) => '${e.key}: ${e.value}').join('\n');
        final text = await AiService.complete(
          cfg: store.ai,
          system:
              '${va.systemPrompt}\n\nWhat you remember about the user:\n$mem\n\nTool: ${widget.tool.title} — ${widget.tool.blurb}',
          user: inputText.isEmpty ? '(no input given)' : inputText,
        );
        if (!mounted) return;
        setState(() {
          _result = text;
          _resultWasLive = true;
        });
      } else {
        final text = DemoEngine.runTool(
            va.id, widget.tool.id, inputs, profile.fields, store);
        if (!mounted) return;
        setState(() {
          _result = text;
          _resultWasLive = false;
        });
      }
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _result = 'The live AI hit a snag: ${e.message}\n\n'
            'Switch back to demo mode for an on-device answer.';
        _resultWasLive = true;
      });
    } catch (e) {
      debugPrint('Tasky tool run failed: $e');
      if (!mounted) return;
      setState(() {
        _result = 'Something went wrong running that. Try again?';
        _resultWasLive = false;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final va = VaDefs.get(widget.vaId);
    final store = context.watch<AppStore>();
    final profile = store.profileOf(va.id);
    final name = va.displayName(profile.customName);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.tool.glyph} ${widget.tool.title}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: store.ai.configured
                  ? GestureDetector(
                      onTap: () =>
                          setState(() => _useLiveAi = !_useLiveAi),
                      child: _useLiveAi
                          ? const LiveBadge()
                          : const DemoBadge(),
                    )
                  : const DemoBadge(),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text('$name · ${va.subtitle()}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: va.colorA)),
          const SizedBox(height: 4),
          Text(widget.tool.blurb,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.65))),
          const SizedBox(height: 16),
          if (widget.tool.inputs.isNotEmpty)
            ToolForm(key: _formKey, fields: widget.tool.inputs),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _run,
            style: FilledButton.styleFrom(
              backgroundColor: va.colorA,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(widget.tool.inputs.isEmpty ? 'Generate' : 'Run',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          if (!store.ai.configured) ...[
            const SizedBox(height: 12),
            Text(
              'Demo mode: answers are generated on-device. Connect a live AI key in Profile → AI for full AI answers.',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55)),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${widget.tool.glyph} Result',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800)),
                        const Spacer(),
                        _resultWasLive
                            ? const LiveBadge()
                            : const DemoBadge(),
                      ],
                    ),
                    const Divider(height: 20),
                    SelectableText(_result!,
                        style: const TextStyle(fontSize: 14, height: 1.55)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================= list tool
class ListToolPage extends StatelessWidget {
  final String vaId;
  final ToolDef tool;

  const ListToolPage({super.key, required this.vaId, required this.tool});

  @override
  Widget build(BuildContext context) {
    final va = VaDefs.get(vaId);
    final store = context.watch<AppStore>();
    final items = store.collectionOf(tool.listKey);

    return Scaffold(
      appBar: AppBar(
        title: Text('${tool.glyph} ${tool.title}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editItem(context, null),
        backgroundColor: va.colorA,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add', style: TextStyle(color: Colors.white)),
      ),
      body: items.isEmpty
          ? EmptyState(
              glyph: tool.glyph,
              title: 'Nothing here yet',
              body: 'Tap Add to create your first ${tool.title.toLowerCase()} entry.',
              buttonLabel: 'Add one',
              onButton: () => _editItem(context, null),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final item = items[i];
                final checked = tool.checkField.isNotEmpty &&
                    item[tool.checkField] == 'true';
                final title = item[tool.itemFields.first.key] ?? '';
                final subtitle = tool.itemFields
                    .skip(1)
                    .where((f) =>
                        f.key != tool.checkField &&
                        (item[f.key] ?? '').isNotEmpty)
                    .map((f) {
                      var v = item[f.key] ?? '';
                      if (f.type == FieldType.date) {
                        final d = DateTime.tryParse(v);
                        if (d != null) {
                          v = DateFormat('MMM d, yyyy').format(d);
                        }
                      }
                      return v;
                    })
                    .join(' · ');
                return Card(
                  child: ListTile(
                    leading: tool.checkField.isNotEmpty
                        ? Checkbox(
                            value: checked,
                            activeColor: va.colorA,
                            onChanged: (_) => store.toggleCollectionCheck(
                                tool.listKey,
                                item['id'] ?? '',
                                tool.checkField),
                          )
                        : Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: va.colorA.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(tool.glyph,
                                style: const TextStyle(fontSize: 20)),
                          ),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration:
                            checked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: subtitle.isEmpty ? null : Text(subtitle),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') {
                          _editItem(context, item);
                        } else if (v == 'delete') {
                          _deleteItem(context, item);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                    onTap: () => _editItem(context, item),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _editItem(
      BuildContext context, Map<String, String>? existing) async {
    final store = context.read<AppStore>();
    final formKey = GlobalKey<ToolFormState>();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing == null ? 'Add ${tool.title}' : 'Edit',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            ToolForm(
                key: formKey,
                fields: tool.itemFields,
                initial: existing ?? {}),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && context.mounted) {
      final values = formKey.currentState?.values() ?? {};
      if (existing == null) {
        store.addCollectionItem(tool.listKey, values);
        showSnack(context, 'Added.');
      } else {
        store.updateCollectionItem(tool.listKey, existing['id'] ?? '', values);
        showSnack(context, 'Saved.');
      }
    }
  }

  Future<void> _deleteItem(
      BuildContext context, Map<String, String> item) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this?',
      body: 'This entry will be removed from ${tool.title}.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok && context.mounted) {
      context
          .read<AppStore>()
          .deleteCollectionItem(tool.listKey, item['id'] ?? '');
      showSnack(context, 'Deleted.');
    }
  }
}

// ============================================================= reminders
class ReminderPage extends StatelessWidget {
  final String vaId;

  const ReminderPage({super.key, required this.vaId});

  @override
  Widget build(BuildContext context) {
    final va = VaDefs.get(vaId);
    final store = context.watch<AppStore>();
    final now = DateTime.now();
    final items = store.reminders;

    return Scaffold(
      appBar: AppBar(
        title: const Text('⏰ Reminders',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addReminder(context),
        backgroundColor: va.colorA,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          if (!NotifyService.ready)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'Notifications aren\'t available on this device right now — reminders will be saved but silent.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(
                    glyph: '⏰',
                    title: 'No reminders yet',
                    body:
                        'Add one and I\'ll nudge you at just the right moment.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final r = items[i];
                      final past = r.at.isBefore(now);
                      final rva = VaDefs.get(r.vaId);
                      return Card(
                        child: ListTile(
                          leading: VaAvatar(va: rva, size: 40),
                          title: Text(r.title,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: past
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.5)
                                      : null)),
                          subtitle: Text(
                            '${DateFormat('MMM d, h:mm a').format(r.at)}${r.note.isNotEmpty ? ' · ${r.note}' : ''}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteReminder(context, r),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _addReminder(BuildContext context) async {
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime when =
        DateTime.now().add(const Duration(hours: 1));
    when = DateTime(when.year, when.month, when.day, when.hour, 0);

    final picked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('New reminder',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration:
                    const InputDecoration(labelText: 'What should I remind you about?'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration:
                    const InputDecoration(labelText: 'Note (optional)'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(DateFormat('MMM d, yyyy').format(when)),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: when,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) {
                          setS(() => when = DateTime(
                              d.year, d.month, d.day, when.hour, when.minute));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(DateFormat('h:mm a').format(when)),
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(when),
                        );
                        if (t != null) {
                          setS(() => when = DateTime(when.year, when.month,
                              when.day, t.hour, t.minute));
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != true || !context.mounted) return;
    final title = titleCtrl.text.trim();
    if (title.isEmpty) {
      showSnack(context, 'Give your reminder a title.');
      return;
    }
    if (when.isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
      showSnack(context, 'Pick a time in the future.');
      return;
    }
    // Consequential: confirm BEFORE anything is scheduled.
    final ok = await confirmDialog(
      context,
      title: 'Schedule reminder?',
      body:
          '"$title"\n${DateFormat('MMM d, h:mm a').format(when)}${noteCtrl.text.trim().isNotEmpty ? '\n${noteCtrl.text.trim()}' : ''}',
      confirmLabel: 'Schedule',
    );
    if (!ok || !context.mounted) return;

    final granted = await PermissionService.ensureNotifications(context);
    if (!context.mounted) return;
    if (!granted) {
      showSnack(context,
          'Reminder saved, but it will be silent without notification permission.');
    }
    final store = context.read<AppStore>();
    final id = store.uuid.v4();
    store.addReminder(ReminderItem(
      id: id,
      vaId: vaId,
      title: title,
      note: noteCtrl.text.trim(),
      at: when,
    ));
    await NotifyService.scheduleReminder(
      id: id.hashCode & 0x7fffffff,
      title: '⏰ $title',
      body: noteCtrl.text.trim().isEmpty
          ? 'From your Tasky assistant'
          : noteCtrl.text.trim(),
      when: when,
    );
    if (context.mounted) showSnack(context, 'Reminder scheduled. ✅');
  }

  Future<void> _deleteReminder(
      BuildContext context, ReminderItem r) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete reminder?',
      body: '"${r.title}" will be cancelled.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await NotifyService.cancel(r.id.hashCode & 0x7fffffff);
    if (context.mounted) {
      context.read<AppStore>().deleteReminder(r.id);
      showSnack(context, 'Reminder deleted.');
    }
  }
}

// ============================================================ study timer
class TimerPage extends StatefulWidget {
  final String vaId;
  const TimerPage({super.key, required this.vaId});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  int _totalSeconds = 25 * 60;
  int _left = 25 * 60;
  Timer? _timer;
  bool _running = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setMinutes(int m) {
    _timer?.cancel();
    setState(() {
      _totalSeconds = m * 60;
      _left = m * 60;
      _running = false;
    });
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_left <= 1) {
        t.cancel();
        setState(() {
          _left = 0;
          _running = false;
        });
        NotifyService.showNow(
          id: 9001,
          title: '⏱️ Focus session complete!',
          body: 'Nice work — take a 5-minute break. You earned it.',
        );
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Session complete! 🎉'),
              content: const Text(
                  'Take a 5-minute break — stretch, water, fresh air. Then go again!'),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        }
        return;
      }
      setState(() => _left--);
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _left = _totalSeconds;
      _running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final va = VaDefs.get(widget.vaId);
    final minutes = _left ~/ 60;
    final seconds = _left % 60;
    final progress =
        _totalSeconds == 0 ? 0.0 : 1 - _left / _totalSeconds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('⏱️ Study Timer',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [15, 25, 50].map((m) {
                final selected = _totalSeconds == m * 60;
                return ChoiceChip(
                  label: Text('$m min'),
                  selected: selected,
                  onSelected: (_) => _setMinutes(m),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 240,
              height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 16,
                      backgroundColor: va.colorA.withValues(alpha: 0.15),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(va.colorA),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            fontSize: 52, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        _running ? 'Focusing…' : 'Paused',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _toggle,
                  style: FilledButton.styleFrom(
                    backgroundColor: va.colorA,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                  ),
                  icon: Icon(
                      _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white),
                  label: Text(_running ? 'Pause' : 'Start',
                      style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _reset,
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              '25 minutes of focus, 5 minutes of break — the classic recipe.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================= scan notes
class ScanPage extends StatefulWidget {
  final String vaId;
  final ToolDef tool;
  const ScanPage({super.key, required this.vaId, required this.tool});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  String? _fileName;
  String? _filePath;
  String? _summary;
  bool _busy = false;

  Future<void> _takePhoto() async {
    final ok = await PermissionService.ensureCamera(context);
    if (!ok || !mounted) return;
    await _pick(ImageSource.camera);
  }

  Future<void> _pick(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
          source: source, maxWidth: 1600, imageQuality: 85);
      if (x != null && mounted) {
        setState(() {
          _fileName = x.name;
          _filePath = x.path;
        });
        _summarize();
      }
    } catch (e) {
      debugPrint('Tasky image pick failed: $e');
      if (mounted) showSnack(context, 'Couldn\'t pick that image.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFile() async {
    setState(() => _busy = true);
    try {
      // file_picker uses the system picker (SAF) — no storage permission needed.
      final files = await FilePicker.pickFiles();
      if (files.isNotEmpty && mounted) {
        final f = files.first;
        setState(() {
          _fileName = f.name;
          _filePath = f.path;
        });
        _summarize();
      }
    } catch (e) {
      debugPrint('Tasky file pick failed: $e');
      if (mounted) showSnack(context, 'Couldn\'t pick that file.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _summarize() {
    // Honest demo: we can't OCR on-device, so we produce a structured
    // study template personalized from memory instead of pretending.
    final store = context.read<AppStore>();
    final profile = store.profileOf(widget.vaId);
    final subjects = (profile.fields['subjects'] ?? '').trim();
    setState(() {
      _summary = '📝 Study sheet — ${_fileName ?? 'your notes'}\n\n'
          'Demo mode can\'t read the file\'s contents yet (on-device OCR isn\'t built in), '
          'so here\'s your study template instead:\n\n'
          '1. KEY TERMS — list each new term in your own words\n'
          '2. CORE IDEAS — the 3 big ideas on this page\n'
          '3. QUESTIONS — what confused you? Ask me in chat!\n'
          '4. ONE-SENTENCE SUMMARY — the whole page in one line\n\n'
          '${subjects.isNotEmpty ? 'Your subjects: $subjects\n\n' : ''}'
          'Fill it in by hand — that\'s where the learning happens. 💪';
    });
  }

  Future<void> _saveNote() async {
    if (_fileName == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Save study note?',
      body: 'Save "$_fileName" to your study notes with this summary?',
      confirmLabel: 'Save',
    );
    if (!ok || !mounted) return;
    context.read<AppStore>().addCollectionItem('study_notes', {
      'title': _fileName ?? 'Scanned notes',
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'note': (_summary ?? '').split('\n').take(3).join(' '),
      'path': _filePath ?? '',
    });
    if (mounted) showSnack(context, 'Study note saved. 📚');
  }

  @override
  Widget build(BuildContext context) {
    final va = VaDefs.get(widget.vaId);
    return Scaffold(
      appBar: AppBar(
        title: Text('📷 ${widget.tool.title}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(widget.tool.blurb,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.65))),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PickButton(
                  glyph: '📷',
                  label: 'Take photo',
                  color: va.colorA,
                  onTap: _busy ? null : _takePhoto,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickButton(
                  glyph: '🖼️',
                  label: 'Choose image',
                  color: va.colorB,
                  onTap: _busy ? null : () => _pick(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickButton(
                  glyph: '📄',
                  label: 'Choose file',
                  color: va.colorA,
                  onTap: _busy ? null : _pickFile,
                ),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_filePath != null &&
              (_filePath!.endsWith('.jpg') ||
                  _filePath!.endsWith('.jpeg') ||
                  _filePath!.endsWith('.png'))) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(_filePath!), height: 200, fit: BoxFit.cover),
            ),
          ],
          if (_summary != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('Summary',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        Spacer(),
                        DemoBadge(),
                      ],
                    ),
                    const Divider(height: 20),
                    SelectableText(_summary!,
                        style:
                            const TextStyle(fontSize: 14, height: 1.55)),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _saveNote,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save as study note'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  final String glyph;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _PickButton(
      {required this.glyph,
      required this.label,
      required this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0.08)
            ],
          ),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(glyph, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ============================================================ VA memory
class MemoryPage extends StatefulWidget {
  final String vaId;
  const MemoryPage({super.key, required this.vaId});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  late TextEditingController _nameCtrl;
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, String> _choices = {};

  @override
  void initState() {
    super.initState();
    final va = VaDefs.get(widget.vaId);
    final store = context.read<AppStore>();
    final profile = store.profileOf(va.id);
    _nameCtrl = TextEditingController(text: profile.customName);
    for (final f in va.memoryFields) {
      _ctrls[f.key] = TextEditingController(text: profile.fields[f.key] ?? '');
      if (f.type == FieldType.choice && f.options.isNotEmpty) {
        _choices[f.key] = profile.fields[f.key] ?? f.options.first;
        if (!f.options.contains(_choices[f.key])) {
          _choices[f.key] = f.options.first;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final va = VaDefs.get(widget.vaId);
    final fields = <String, String>{};
    for (final f in va.memoryFields) {
      fields[f.key] = f.type == FieldType.choice
          ? (_choices[f.key] ?? '')
          : (_ctrls[f.key]?.text.trim() ?? '');
    }
    final store = context.read<AppStore>();
    store.updateVaProfile(widget.vaId,
        customName: _nameCtrl.text.trim(), fields: fields);
    if (mounted) {
      showSnack(context, 'Memory saved — I\'ll use this to personalize your results. 🧠');
      Navigator.of(context).pop();
    }
  }

  Future<void> _reset() async {
    final ok = await confirmDialog(
      context,
      title: 'Reset memory?',
      body: 'This clears everything this assistant remembers about you.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final va = VaDefs.get(widget.vaId);
    context
        .read<AppStore>()
        .updateVaProfile(widget.vaId, customName: '', fields: {
      for (final f in va.memoryFields) f.key: ''
    });
    if (mounted) {
      showSnack(context, 'Memory cleared.');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final va = VaDefs.get(widget.vaId);
    final store = context.watch<AppStore>();
    final profile = store.profileOf(va.id);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('🧠 ${va.displayName(profile.customName)}\'s memory',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(onPressed: _reset, child: const Text('Reset')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              VaAvatar(va: va, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'What I remember about you. I use this to personalize every result — it never leaves this device.',
                  style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurface.withValues(alpha: 0.65)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Assistant name (e.g. James)',
              hintText: 'Leave blank to use the default',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 6),
          Text(
            'Cards and headers always show the type too — e.g. "James, ${va.subtitle()}".',
            style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 16),
          for (final f in va.memoryFields) ...[
            f.type == FieldType.choice
                ? DropdownButtonFormField<String>(
                    initialValue: _choices[f.key],
                    decoration: InputDecoration(
                        labelText: f.label, hintText: f.hint),
                    items: [
                      for (final o in f.options)
                        DropdownMenuItem(value: o, child: Text(o)),
                    ],
                    onChanged: (v) =>
                        setState(() => _choices[f.key] = v ?? ''),
                  )
                : TextField(
                    controller: _ctrls[f.key],
                    decoration: InputDecoration(
                        labelText: f.label, hintText: f.hint),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    minLines: 1,
                  ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: va.colorA,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Save memory',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
