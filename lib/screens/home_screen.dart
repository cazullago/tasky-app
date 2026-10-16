import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../va_defs.dart';
import '../widgets/ui.dart';
import 'profile_screen.dart';
import 'va_screen.dart';

String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

/// Home: greeting, one big VA hub card, avatar top-right -> profile.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final now = DateTime.now();
    final scheme = Theme.of(context).colorScheme;

    final tasks = store.collectionOf('life_tasks');
    final openTasks = tasks.where((t) => t['done'] != 'true').length;
    final upcomingReminders = store.reminders
        .where((r) => r.at.isAfter(now.subtract(const Duration(minutes: 5))))
        .length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: Text(
              'Tasky',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 24,
                letterSpacing: -0.5,
                color: scheme.onSurface,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _AvatarButton(),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${greetingFor(now)} 👋',
                    style:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    store.userName.isEmpty
                        ? 'What would you like to do?'
                        : '${store.userName}, what would you like to do?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.65),
                        ),
                  ),
                  const SizedBox(height: 20),
                  // ---- the ONE big central VA card ----
                  _HubCard(),
                  const SizedBox(height: 16),
                  // ---- today at a glance ----
                  Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          glyph: '✅',
                          label: '$openTasks open tasks',
                          onTap: () => _openVa(context, VaIds.life, 'my_tasks'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatChip(
                          glyph: '⏰',
                          label: '$upcomingReminders reminders',
                          onTap: () => _openVa(context, VaIds.life, 'reminders'),
                        ),
                      ),
                    ],
                  ),
                  const SectionTitle(text: 'Meet your assistants'),
                  _MiniVaRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openVa(BuildContext context, String vaId, String toolId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VaScreen(vaId: vaId, initialToolId: toolId),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final photo = store.photoPath;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: AppTheme.heroGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Theme.of(context).colorScheme.surface,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipOval(
          child: photo != null && File(photo).existsSync()
              ? Image.file(File(photo), fit: BoxFit.cover)
              : Center(
                  child: Text(
                    store.userName.isEmpty
                        ? '🙂'
                        : store.userName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ChooseVaScreen()),
      ),
      child: Hero(
        tag: 'va-hub',
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppTheme.heroGradient,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.4),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var i = 0; i < 4; i++)
                    Align(
                      widthFactor: 0.62,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [
                            VaDefs.all[i].colorA,
                            VaDefs.all[i].colorB,
                          ]),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(VaDefs.all[i].glyph,
                            style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('7 VAs',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Your personal AI assistants',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '7 specialized assistants for life, business, creativity, home, messages, travel & study.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tap to explore',
                      style: TextStyle(
                        color: AppTheme.primaryDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded,
                        color: AppTheme.primaryDeep, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String glyph;
  final String label;
  final VoidCallback onTap;

  const _StatChip(
      {required this.glyph, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Text(glyph, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style:
                        const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniVaRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final vas = VaDefs.all;
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: vas.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final va = vas[i];
          final profile = store.profileOf(va.id);
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => VaScreen(vaId: va.id)),
            ),
            child: Container(
              width: 92,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    va.colorA.withValues(alpha: 0.16),
                    va.colorB.withValues(alpha: 0.10),
                  ],
                ),
                border: Border.all(
                    color: va.colorA.withValues(alpha: 0.25)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  VaAvatar(va: va, size: 44),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      va.displayName(profile.customName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Choose Your Assistant: 7 large expressive cards, renameable.
class ChooseVaScreen extends StatelessWidget {
  const ChooseVaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Assistant',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: VaDefs.all.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, i) {
          final va = VaDefs.all[i];
          final profile = store.profileOf(va.id);
          return _VaCard(va: va, profile: profile);
        },
      ),
    );
  }
}

class _VaCard extends StatelessWidget {
  final VaDef va;
  final VaProfile profile;

  const _VaCard({required this.va, required this.profile});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VaScreen(vaId: va.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              va.colorA.withValues(alpha: 0.20),
              va.colorB.withValues(alpha: 0.10),
              scheme.surface,
            ],
          ),
          border: Border.all(color: va.colorA.withValues(alpha: 0.30)),
          boxShadow: [
            BoxShadow(
              color: va.colorA.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            VaAvatar(va: va, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    va.displayName(profile.customName),
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    va.subtitle(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: va.colorA,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    va.tagline,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${va.tools.length} tools',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  tooltip: 'Rename',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _rename(context),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurface.withValues(alpha: 0.4)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final store = context.read<AppStore>();
    final controller =
        TextEditingController(text: profile.customName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename your ${va.noun} assistant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Name (e.g. James)',
                hintText: va.title,
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            Text(
              'The card and headers will always show its type too — e.g. "James, your business assistant".',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          if (profile.customName.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(''),
              child: const Text('Reset'),
            ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && context.mounted) {
      store.updateVaProfile(va.id, customName: result);
      showSnack(
          context,
          result.isEmpty
              ? 'Name reset.'
              : 'Meet $result, ${va.subtitle()}!');
    }
  }
}
