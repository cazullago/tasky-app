import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'theme.dart';

/// Section header used across screens.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader(
      {super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Rounded premium card wrapper.
class TaskyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const TaskyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: taskyCardDeco(context),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: t.colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 30, color: t.colorScheme.primary),
          ),
          const SizedBox(height: 12),
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: t.brightness == Brightness.dark
                      ? TaskyColors.inkSoftDark
                      : TaskyColors.inkSoft)),
        ],
      ),
    );
  }
}

Color priorityColor(String p) {
  switch (p) {
    case 'high':
      return const Color(0xFFD64545);
    case 'medium':
      return TaskyColors.amber;
    default:
      return const Color(0xFF4CAF7D);
  }
}

String priorityLabel(String p) =>
    p.isEmpty ? p : p[0].toUpperCase() + p.substring(1);

String fmtDate(DateTime? d) =>
    d == null ? '' : DateFormat('MMM d, yyyy').format(d);

String fmtTime(String? hhmm) {
  if (hhmm == null || hhmm.isEmpty) return '';
  final p = hhmm.split(':');
  var h = int.parse(p[0]);
  final ap = h >= 12 ? 'PM' : 'AM';
  h = h % 12 == 0 ? 12 : h % 12;
  return '$h:${p[1]} $ap';
}

/// Renders an [ActionCard] inside the assistant chat with explicit
/// confirm / secondary buttons. Nothing executes until confirmed.
class ActionCardView extends StatefulWidget {
  final ActionCard card;
  final bool resolved;
  final Future<void> Function(ActionCard card) onConfirm;
  final VoidCallback? onSecondary;

  const ActionCardView({
    super.key,
    required this.card,
    required this.resolved,
    required this.onConfirm,
    this.onSecondary,
  });

  @override
  State<ActionCardView> createState() => _ActionCardViewState();
}

class _ActionCardViewState extends State<ActionCardView> {
  bool _busy = false;
  bool _showDraft = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final card = widget.card;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: t.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: t.colorScheme.primary.withOpacity(0.35), width: 1.2),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: t.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconFor(card.kind),
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(card.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (card.kind == 'email' && !_showDraft)
            Text(card.lines.first,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          if (card.kind != 'email' || _showDraft)
            ...card.lines.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                          child: Text(l,
                              style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                )),
          const SizedBox(height: 12),
          if (widget.resolved)
            Row(
              children: [
                Icon(Icons.check_circle,
                    color: t.colorScheme.primary, size: 18),
                const SizedBox(width: 6),
                const Text('Done',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            await widget.onConfirm(card);
                            if (mounted) setState(() => _busy = false);
                          },
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(card.confirmLabel),
                  ),
                ),
                if (card.secondaryLabel != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        if (card.kind == 'email' && !_showDraft) {
                          setState(() => _showDraft = true);
                        } else {
                          widget.onSecondary?.call();
                        }
                      },
                      child: Text(card.secondaryLabel!),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'reminder':
        return Icons.alarm;
      case 'task':
        return Icons.check_circle_outline;
      case 'email':
        return Icons.mail_outline;
      case 'delete':
        return Icons.delete_outline;
      default:
        return Icons.bolt;
    }
  }
}

/// Small "Demo mode" / "Live API" badge.
class ProviderBadge extends StatelessWidget {
  final String text;
  final bool live;

  const ProviderBadge({super.key, required this.text, this.live = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = live ? t.colorScheme.primary : TaskyColors.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.5)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: c)),
    );
  }
}

/// Confirm dialog used for destructive actions.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm Delete',
  String cancelLabel = 'Cancel',
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return res ?? false;
}
