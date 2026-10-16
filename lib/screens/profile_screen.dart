import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../ai.dart';
import '../auth.dart';
import '../models.dart';
import '../notify.dart';
import '../perms.dart';
import '../store.dart';
import '../widgets/ui.dart';

/// Profile: photo, name, email, settings, AI provider, legal placeholders,
/// log out, data/account deletion.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final photo = store.photoPath;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => _pickPhoto(context),
                  child: Stack(
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF6C4CF1),
                              Color(0xFFB16CEA)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
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
                                        fontSize: 44,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surface,
                                width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_outlined,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(store.userName,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900)),
                if (store.userEmail.isNotEmpty)
                  Text(store.userEmail,
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6))),
                const SizedBox(height: 4),
                const DemoBadge(),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit info'),
                  onPressed: () => _editInfo(context),
                ),
              ],
            ),
          ),
          const SectionTitle(text: 'Settings'),
          _MenuTile(
            icon: Icons.tune_outlined,
            title: 'App settings',
            subtitle: 'Appearance, voice input, permissions',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          _MenuTile(
            icon: Icons.psychology_outlined,
            title: 'AI provider',
            subtitle: store.ai.configured
                ? 'Live AI configured (${store.ai.model})'
                : 'Demo mode — connect your own AI key',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
            ),
          ),
          _MenuTile(
            icon: Icons.workspace_premium_outlined,
            title: 'Tasky Premium',
            subtitle: 'Coming soon',
            onTap: () => _placeholder(
                context, 'Tasky Premium', 'Premium plans aren\'t available yet. Everything in Tasky is free for now. 💛'),
          ),
          const SectionTitle(text: 'Privacy & legal'),
          _MenuTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => _placeholder(context, 'Privacy Policy',
                'Tasky v2.0 stores everything on your device — tasks, chats, memories, and your demo account never leave this phone. A full privacy policy URL will be added before the Play Store release.'),
          ),
          _MenuTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () => _placeholder(context, 'Terms of Service',
                'Short version: be kind, don\'t misuse the app, and remember demo-mode answers are generated on-device. Full terms will be added before the Play Store release.'),
          ),
          _MenuTile(
            icon: Icons.delete_sweep_outlined,
            title: 'Request data deletion',
            subtitle: 'Erase all local Tasky data',
            onTap: () => _wipeData(context),
          ),
          _MenuTile(
            icon: Icons.person_remove_outlined,
            title: 'Delete account',
            subtitle: 'Remove your demo account and data',
            danger: true,
            onTap: () => _deleteAccount(context),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
            onPressed: () => _logOut(context),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Tasky 2.0.0 · made with care',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(ctx).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove photo'),
              onTap: () => Navigator.of(ctx).pop('remove'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'remove') {
      context.read<AppStore>().clearPhoto();
      showSnack(context, 'Photo removed.');
      return;
    }
    final source =
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    if (source == ImageSource.camera) {
      final ok = await PermissionService.ensureCamera(context);
      if (!ok || !context.mounted) return;
    }
    try {
      final x = await ImagePicker()
          .pickImage(source: source, maxWidth: 800, imageQuality: 85);
      if (x != null && context.mounted) {
        context.read<AppStore>().updateProfile(photo: x.path);
        showSnack(context, 'Profile photo updated. 📸');
      }
    } catch (_) {
      if (context.mounted) showSnack(context, 'Couldn\'t pick a photo.');
    }
  }

  Future<void> _editInfo(BuildContext context) async {
    final store = context.read<AppStore>();
    final nameCtrl = TextEditingController(text: store.userName);
    final emailCtrl = TextEditingController(text: store.userEmail);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true && context.mounted) {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) {
        showSnack(context, 'Name can\'t be empty.');
        return;
      }
      store.updateProfile(name: name, email: emailCtrl.text.trim());
      showSnack(context, 'Profile updated.');
    }
  }

  void _placeholder(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(body),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _wipeData(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete all my data?',
      body:
          'This erases tasks, reminders, chats, VA memories, and settings on this device. This can\'t be undone.',
      confirmLabel: 'Delete everything',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final auth = context.read<AuthService>();
    await context.read<AppStore>().wipeAll();
    await auth.signOut();
    if (context.mounted) showSnack(context, 'All local data deleted.');
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete account?',
      body:
          'Your demo account and all its local data will be removed from this device.',
      confirmLabel: 'Delete account',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final store = context.read<AppStore>();
    final auth = context.read<AuthService>();
    final me = auth.currentUser;
    if (me != null) {
      store.setUsers(store.users.where((u) => u.id != me.id).toList());
      await store.saveUsers();
    }
    await store.wipeAll();
    await auth.signOut();
    if (context.mounted) showSnack(context, 'Account deleted.');
  }

  Future<void> _logOut(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Log out?',
      body: 'You\'ll need your email and password to log back in.',
      confirmLabel: 'Log out',
    );
    if (ok && context.mounted) {
      await context.read<AuthService>().signOut();
    }
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool danger;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.danger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: (danger ? Colors.red : scheme.primary)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon,
              color: danger ? Colors.red : scheme.primary, size: 22),
        ),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: danger ? Colors.red : null)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

// ================================================================ settings
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic> _permStatus = {};
  bool _loadingPerms = true;

  @override
  void initState() {
    super.initState();
    _refreshPerms();
  }

  Future<void> _refreshPerms() async {
    final s = await PermissionService.statuses();
    if (mounted) {
      setState(() {
        _permStatus = s.map((k, v) => MapEntry(k, v.toString().split('.').last));
        _loadingPerms = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final settings = store.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App settings',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const SectionTitle(text: 'Appearance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'system',
                      label: Text('System'),
                      icon: Icon(Icons.settings_suggest_outlined)),
                  ButtonSegment(
                      value: 'light',
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined)),
                  ButtonSegment(
                      value: 'dark',
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined)),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) {
                  store.updateSettings(AppSettings(
                    themeMode: s.first,
                    voiceInput: settings.voiceInput,
                  ));
                },
              ),
            ),
          ),
          const SectionTitle(text: 'Voice input'),
          Card(
            child: SwitchListTile(
              title: const Text('Voice input in chat & tools'),
              subtitle: const Text(
                  'Show the mic button. The microphone is only requested when you tap it.'),
              value: settings.voiceInput,
              onChanged: (v) {
                store.updateSettings(AppSettings(
                  themeMode: settings.themeMode,
                  voiceInput: v,
                ));
              },
            ),
          ),
          const SectionTitle(text: 'Permissions'),
          Card(
            child: Column(
              children: [
                if (_loadingPerms)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  )
                else
                  for (final e in _permStatus.entries)
                    ListTile(
                      title: Text(e.key),
                      trailing: Chip(label: Text('${e.value}')),
                    ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Open app settings'),
                        onPressed: () async {
                          await PermissionService.openSettings();
                          _refreshPerms();
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tasky only asks for a permission right when you need it — microphone for voice input, camera for photos, notifications for reminders.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.55)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle(text: 'Notifications'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Send a test notification'),
              subtitle: Text(NotifyService.ready
                  ? 'Check that reminders can reach you'
                  : 'Notifications unavailable on this device'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final ok =
                    await PermissionService.ensureNotifications(context);
                if (!context.mounted) return;
                if (ok) {
                  await NotifyService.showNow(
                    id: 9002,
                    title: '✅ Tasky test',
                    body: 'Reminders are working. Nice!',
                  );
                } else {
                  showSnack(context,
                      'Enable notifications to receive reminders.');
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================= AI settings
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  late TextEditingController _url;
  late TextEditingController _key;
  late TextEditingController _model;
  late bool _enabled;
  bool _testing = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final ai = context.read<AppStore>().ai;
    _url = TextEditingController(text: ai.baseUrl);
    _key = TextEditingController(text: ai.apiKey);
    _model = TextEditingController(text: ai.model);
    _enabled = ai.enabled;
  }

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  void _save() {
    final cfg = AiConfig(
      baseUrl: _url.text.trim().isEmpty
          ? 'https://api.openai.com/v1'
          : _url.text.trim(),
      apiKey: _key.text.trim(),
      model: _model.text.trim().isEmpty ? 'gpt-4o-mini' : _model.text.trim(),
      enabled: _enabled,
    );
    context.read<AppStore>().updateAi(cfg);
    showSnack(context, 'AI settings saved.');
    Navigator.of(context).pop();
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    final cfg = AiConfig(
      baseUrl: _url.text.trim().isEmpty
          ? 'https://api.openai.com/v1'
          : _url.text.trim(),
      apiKey: _key.text.trim(),
      model: _model.text.trim().isEmpty ? 'gpt-4o-mini' : _model.text.trim(),
    );
    try {
      await AiService.testConnection(cfg);
      if (mounted) showSnack(context, '✅ Connection works!');
    } catch (e) {
      if (mounted) showSnack(context, '❌ $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI provider',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const DemoBadge(),
          const SizedBox(height: 8),
          Text(
            'Without a key, Tasky answers in demo mode (on-device, honest about it). '
            'Add an OpenAI-compatible API key for full live AI answers in every VA\'s chat and tools.',
            style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.65)),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Use live AI when configured'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _url,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'https://api.openai.com/v1',
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'API key',
              hintText: 'sk-…',
              suffixIcon: IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () =>
                    setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _model,
            decoration: const InputDecoration(
              labelText: 'Model',
              hintText: 'gpt-4o-mini',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your key is stored only on this device, and is sent only to the base URL above.',
            style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _test,
                  child: _testing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Test connection'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

