import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../ai.dart';
import '../nav.dart';
import '../notify.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class ProfileScreen extends StatefulWidget {
  final TaskyNav nav;
  const ProfileScreen({super.key, required this.nav});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _apiKey = TextEditingController();
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();
  bool _aiInit = false;

  @override
  void dispose() {
    _apiKey.dispose();
    _baseUrl.dispose();
    _model.dispose();
    super.dispose();
  }

  void _syncAiFields(TaskyStore s) {
    if (_aiInit) return;
    _apiKey.text = s.apiKey;
    _baseUrl.text = s.baseUrl;
    _model.text = s.model;
    _aiInit = true;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskyStore>();
    _syncAiFields(store);
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // ---- header ----
          TaskyCard(
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _pickPhoto(store),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor:
                            t.colorScheme.primary.withOpacity(0.15),
                        backgroundImage: store.photoPath != null
                            ? FileImage(File(store.photoPath!))
                            : null,
                        child: store.photoPath == null
                            ? Text(
                                store.userName.isEmpty
                                    ? '?'
                                    : store.userName[0].toUpperCase(),
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: t.colorScheme.primary),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: t.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store.userName,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(store.email,
                          style: TextStyle(
                              fontSize: 14,
                              color: t.brightness == Brightness.dark
                                  ? TaskyColors.inkSoftDark
                                  : TaskyColors.inkSoft)),
                      Text('Timezone: ${store.timezone}',
                          style: TextStyle(
                              fontSize: 12,
                              color: t.brightness == Brightness.dark
                                  ? TaskyColors.inkSoftDark
                                  : TaskyColors.inkSoft)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editProfile(store),
                ),
              ],
            ),
          ),

          const SectionHeader(title: 'Notifications'),
          TaskyCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable notifications',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text(
                      'Task due dates, reminders, and events'),
                  value: store.notificationsEnabled,
                  onChanged: (v) => _toggleMaster(store, v),
                ),
                const Divider(height: 1),
                _subToggle(
                    store,
                    'Upcoming tasks & reminders',
                    store.notifyUpcoming,
                    (v) => _set(store, () => store.notifyUpcoming = v)),
                _subToggle(
                    store,
                    'Overdue tasks',
                    store.notifyOverdue,
                    (v) => _set(store, () => store.notifyOverdue = v)),
                _subToggle(
                    store,
                    'Calendar events',
                    store.notifyEvents,
                    (v) => _set(store, () => store.notifyEvents = v)),
              ],
            ),
          ),

          const SectionHeader(title: 'AI'),
          TaskyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI provider',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'demo',
                        label: Text('Demo AI'),
                        icon: Icon(Icons.smart_toy_outlined)),
                    ButtonSegment(
                        value: 'http',
                        label: Text('Custom API'),
                        icon: Icon(Icons.cloud_outlined)),
                  ],
                  selected: {store.aiProvider},
                  onSelectionChanged: (s) =>
                      _set(store, () => store.aiProvider = s.first),
                ),
                const SizedBox(height: 8),
                Text(
                  store.aiProvider == 'demo'
                      ? 'On-device demo engine. Fast and offline, but with limited knowledge — great for trying Tasky out.'
                      : 'Bring your own OpenAI-compatible API key for live answers. Your key stays on this device.',
                  style: TextStyle(
                      fontSize: 13,
                      color: t.brightness == Brightness.dark
                          ? TaskyColors.inkSoftDark
                          : TaskyColors.inkSoft),
                ),
                if (store.aiProvider == 'http') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKey,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'API key',
                        hintText: 'sk-…',
                        prefixIcon: Icon(Icons.key_outlined)),
                    onChanged: (v) => store.apiKey = v,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _baseUrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                        labelText: 'Base URL',
                        hintText: 'https://api.openai.com/v1',
                        prefixIcon: Icon(Icons.link_outlined)),
                    onChanged: (v) => store.baseUrl = v,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _model,
                    decoration: const InputDecoration(
                        labelText: 'Model',
                        hintText: 'gpt-4o-mini',
                        prefixIcon: Icon(Icons.psychology_outlined)),
                    onChanged: (v) => store.model = v,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _saveAi(store),
                          child: const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _testConnection(store),
                          child: const Text('Test connection'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: store.aiTone,
                  decoration:
                      const InputDecoration(labelText: 'AI tone'),
                  items: ['Friendly', 'Professional', 'Casual', 'Concise']
                      .map((x) =>
                          DropdownMenuItem(value: x, child: Text(x)))
                      .toList(),
                  onChanged: (v) =>
                      _set(store, () => store.aiTone = v ?? 'Friendly'),
                ),
              ],
            ),
          ),

          const SectionHeader(title: 'Appearance'),
          TaskyCard(
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
              selected: {store.themeMode},
              onSelectionChanged: (s) =>
                  _set(store, () => store.themeMode = s.first),
            ),
          ),

          const SectionHeader(title: 'Privacy'),
          TaskyCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Anonymous usage analytics',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text(
                      'Off by default. Helps improve Tasky if enabled.'),
                  value: store.analyticsEnabled,
                  onChanged: (v) =>
                      _set(store, () => store.analyticsEnabled = v),
                ),
                const Divider(height: 1),
                _linkRow(context, 'Privacy Policy', Icons.privacy_tip_outlined,
                    () => _placeholderDoc(context, 'Privacy Policy',
                        'This is a placeholder. Before release, this screen will host Tasky\'s full Privacy Policy: what data is stored (tasks, reminders, and settings — on this device only), what is never collected, and how to contact us.')),
                _linkRow(context, 'Terms of Service', Icons.description_outlined,
                    () => _placeholderDoc(context, 'Terms of Service',
                        'This is a placeholder. Before release, this screen will host Tasky\'s Terms of Service.')),
                _linkRow(context, 'Request data deletion',
                    Icons.delete_forever_outlined, () => _placeholderDoc(
                        context,
                        'Data deletion request',
                        'This is a placeholder. In the released app you\'ll be able to request deletion of any data Tasky holds. Since v1 stores everything on this device only, use "Erase all local data" below to wipe it now.')),
                _linkRow(context, 'Delete account',
                    Icons.person_remove_outlined, () => _placeholderDoc(
                        context,
                        'Delete account',
                        'This is a placeholder. Tasky v1 has no cloud account — all data lives on this device. Use "Erase all local data" below to remove everything.')),
              ],
            ),
          ),

          const SectionHeader(title: 'Subscription'),
          TaskyCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: TaskyColors.amber.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.workspace_premium,
                      color: TaskyColors.amber),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tasky Pro — coming soon',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      SizedBox(height: 2),
                      Text('Priority AI, unlimited history, team workspaces.',
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
            onPressed: () => _placeholderDoc(context, 'Log out',
                'This is a placeholder. Tasky v1 has no cloud account, so there\'s nothing to log out from yet.'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () async {
              final ok = await confirmDialog(context,
                  title: 'Erase all local data?',
                  message:
                      'Removes all tasks, reminders, events, chat, and settings on this device, then restores the demo data.',
                  confirmLabel: 'Erase');
              if (ok) {
                await store.resetDemoData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Demo data restored.')));
                }
              }
            },
            child: const Text('Erase all local data'),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Tasky v1.0.0+1 · Demo build',
                style: TextStyle(
                    fontSize: 12,
                    color: t.brightness == Brightness.dark
                        ? TaskyColors.inkSoftDark
                        : TaskyColors.inkSoft)),
          ),
        ],
      ),
    );
  }

  void _set(TaskyStore store, void Function() fn) {
    fn();
    store.persist();
    NotifyService.reschedule(store);
  }

  Widget _subToggle(
      TaskyStore store, String label, bool value, void Function(bool) on) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value && store.notificationsEnabled,
      onChanged: store.notificationsEnabled ? on : null,
    );
  }

  Future<void> _toggleMaster(TaskyStore store, bool v) async {
    if (!v) {
      _set(store, () => store.notificationsEnabled = false);
      return;
    }
    final allow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Allow notifications?'),
        content: const Text(
            'Tasky will send you notifications for upcoming tasks, overdue items, calendar events, and recurring reminders — so nothing slips. You can change this anytime in Settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Not now')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Allow')),
        ],
      ),
    );
    if (allow == true) {
      final granted = await NotifyService.requestPermission();
      _set(store, () => store.notificationsEnabled = granted);
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Permission denied — enable notifications in Android Settings to receive reminders.')));
      }
    }
  }

  Future<void> _pickPhoto(TaskyStore store) async {
    try {
      final img = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 512);
      if (img == null) return;
      store.photoPath = img.path;
      await store.persist();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn\'t open the photo picker.')));
      }
    }
  }

  Future<void> _editProfile(TaskyStore store) async {
    final name = TextEditingController(text: store.userName);
    final email = TextEditingController(text: store.email);
    final tzc = TextEditingController(text: store.timezone);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 8),
            TextField(
                controller: tzc,
                decoration: const InputDecoration(
                    labelText: 'Timezone (e.g. Asia/Manila)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      _set(store, () {
        if (name.text.trim().isNotEmpty) {
          store.userName = name.text.trim();
        }
        store.email = email.text.trim();
        if (tzc.text.trim().isNotEmpty) {
          store.timezone = tzc.text.trim();
        }
      });
    }
    name.dispose();
    email.dispose();
    tzc.dispose();
  }

  Future<void> _saveAi(TaskyStore store) async {
    await store.persist();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI settings saved.')));
    }
  }

  Future<void> _testConnection(TaskyStore store) async {
    await store.persist();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Testing connection…'),
          ],
        ),
      ),
    );
    String result;
    try {
      final p = buildProvider(
        providerId: 'http',
        apiKey: store.apiKey,
        baseUrl: store.baseUrl,
        model: store.model,
        tone: store.aiTone,
      );
      final reply = await p.generate(
          'Reply with exactly: OK',
          AiContext(userName: store.userName, tasks: store.tasks));
      result = reply.text.length > 300
          ? '${reply.text.substring(0, 300)}…'
          : reply.text;
    } catch (e) {
      result = 'Failed: $e';
    }
    if (mounted) {
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('Connection test'),
          content: Text(result),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close')),
          ],
        ),
      );
    }
  }

  Widget _linkRow(
      BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
      dense: true,
    );
  }

  void _placeholderDoc(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close')),
        ],
      ),
    );
  }
}
