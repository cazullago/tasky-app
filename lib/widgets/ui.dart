import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models.dart';
import '../perms.dart';
import '../store.dart';

/// Original gradient avatar for a VA: gradient disc + glyph, drawn in code.
class VaAvatar extends StatelessWidget {
  final VaDef va;
  final double size;
  final String? customName;

  const VaAvatar({super.key, required this.va, this.size = 56, this.customName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [va.colorA, va.colorB],
        ),
        boxShadow: [
          BoxShadow(
            color: va.colorA.withValues(alpha: 0.35),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        va.glyph,
        style: TextStyle(fontSize: size * 0.48),
      ),
    );
  }
}

/// Small chip marking on-device demo output. Honest, always visible.
class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Text(
        'DEMO MODE',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: scheme.primary,
        ),
      ),
    );
  }
}

class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
      ),
      child: const Text(
        'LIVE AI',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Colors.green,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionTitle({super.key, required this.text, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          Text(
            text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String glyph;
  final String title;
  final String body;
  final String? buttonLabel;
  final VoidCallback? onButton;

  const EmptyState({
    super.key,
    required this.glyph,
    required this.title,
    required this.body,
    this.buttonLabel,
    this.onButton,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(glyph, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.65))),
            if (buttonLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onButton, child: Text(buttonLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Confirm / Cancel dialog for consequential actions. Returns true on confirm.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: Colors.red)
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

void showSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Dynamic tool input form. Parent reads values via [ToolFormState.values].
class ToolForm extends StatefulWidget {
  final List<FieldDef> fields;
  final Map<String, String> initial;

  const ToolForm({super.key, required this.fields, this.initial = const {}});

  @override
  State<ToolForm> createState() => ToolFormState();
}

class ToolFormState extends State<ToolForm> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _choices = {};
  final Map<String, DateTime?> _dates = {};
  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;
  String? _listeningKey;

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      _controllers[f.key] =
          TextEditingController(text: widget.initial[f.key] ?? '');
      if (f.type == FieldType.choice && f.options.isNotEmpty) {
        _choices[f.key] = widget.initial[f.key] ?? f.options.first;
      }
      if (f.type == FieldType.date) {
        final raw = widget.initial[f.key];
        _dates[f.key] = raw == null ? null : DateTime.tryParse(raw);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    try {
      _speech.cancel();
    } catch (_) {}
    super.dispose();
  }

  Map<String, String> values() {
    final out = <String, String>{};
    for (final f in widget.fields) {
      switch (f.type) {
        case FieldType.choice:
          out[f.key] = _choices[f.key] ?? '';
          break;
        case FieldType.date:
          final d = _dates[f.key];
          out[f.key] = d == null ? '' : DateFormat('yyyy-MM-dd').format(d);
          break;
        default:
          out[f.key] = _controllers[f.key]?.text.trim() ?? '';
      }
    }
    return out;
  }

  Future<void> _toggleMic(String key) async {
    final store = context.read<AppStore>();
    if (!store.settings.voiceInput) {
      showSnack(context, 'Voice input is off (Profile → Settings).');
      return;
    }
    try {
      if (!_speechReady) {
        _speechReady = await _speech.initialize(
          onError: (_) {},
          onStatus: (_) {},
        );
      }
      if (!mounted) return;
      if (!_speechReady) {
        showSnack(context, 'Voice input isn\'t available on this device.');
        return;
      }
      if (_listeningKey == key) {
        await _speech.stop();
        if (mounted) setState(() => _listeningKey = null);
        return;
      }
      final ok = await PermissionService.ensureMicrophone(context);
      if (!ok || !mounted) return;
      setState(() => _listeningKey = key);
      final controller = _controllers[key];
      await _speech.listen(
        onResult: (r) {
          controller?.text = r.recognizedWords;
          controller?.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
        },
        listenOptions:
            SpeechListenOptions(listenFor: const Duration(seconds: 30)),
      );
      await Future.delayed(const Duration(seconds: 31));
      if (mounted && _listeningKey == key) {
        setState(() => _listeningKey = null);
      }
    } catch (e) {
      debugPrint('Tasky mic failed: $e');
      if (mounted) {
        setState(() => _listeningKey = null);
        showSnack(context, 'Voice input hit a snag.');
      }
    }
  }

  Future<void> _pickDate(String key) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dates[key] ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null && mounted) {
      setState(() => _dates[key] = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in widget.fields) ...[
          _buildField(f),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildField(FieldDef f) {
    switch (f.type) {
      case FieldType.choice:
        return DropdownButtonFormField<String>(
          initialValue: _choices[f.key],
          decoration: InputDecoration(labelText: f.label, hintText: f.hint),
          items: [
            for (final o in f.options)
              DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: (v) => setState(() => _choices[f.key] = v ?? ''),
        );
      case FieldType.date:
        final d = _dates[f.key];
        return InkWell(
          onTap: () => _pickDate(f.key),
          borderRadius: BorderRadius.circular(16),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: f.label,
              hintText: f.hint,
              suffixIcon: const Icon(Icons.calendar_today_outlined),
            ),
            child: Text(
              d == null ? 'Pick a date' : DateFormat('MMM d, yyyy').format(d),
              style: TextStyle(
                  color: d == null
                      ? Theme.of(context).hintColor
                      : Theme.of(context).colorScheme.onSurface),
            ),
          ),
        );
      case FieldType.number:
        return TextField(
          controller: _controllers[f.key],
          decoration: InputDecoration(labelText: f.label, hintText: f.hint),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
        );
      case FieldType.multiline:
        return _textFieldWithMic(f, maxLines: 4);
      case FieldType.text:
        return _textFieldWithMic(f, maxLines: 1);
    }
  }

  Widget _textFieldWithMic(FieldDef f, {required int maxLines}) {
    final listening = _listeningKey == f.key;
    return TextField(
      controller: _controllers[f.key],
      decoration: InputDecoration(
        labelText: f.label,
        hintText: f.hint,
        suffixIcon: IconButton(
          tooltip: listening ? 'Stop listening' : 'Dictate',
          icon: Icon(
            listening ? Icons.mic : Icons.mic_none_outlined,
            color: listening ? Colors.red : null,
          ),
          onPressed: () => _toggleMic(f.key),
        ),
      ),
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
    );
  }
}
