import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nav.dart';
import 'notify.dart';
import 'screens/assistant.dart';
import 'screens/calendar.dart';
import 'screens/home.dart';
import 'screens/profile.dart';
import 'screens/tasks.dart';
import 'screens/tools.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotifyService.init();
  final store = TaskyStore();
  await store.load();
  runApp(
    ChangeNotifierProvider.value(
      value: store,
      child: const TaskyApp(),
    ),
  );
}

class TaskyApp extends StatelessWidget {
  const TaskyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskyStore>();
    return MaterialApp(
      title: 'Tasky',
      debugShowCheckedModeBanner: false,
      theme: taskyTheme(Brightness.light),
      darkTheme: taskyTheme(Brightness.dark),
      themeMode: store.themeModeValue,
      home: const ShellScreen(),
    );
  }
}

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _tab = 0;
  final _assistantKey = GlobalKey<AssistantScreenState>();
  late final TaskyNav _nav;
  Timer? _rescheduleTimer;
  late final VoidCallback _storeListener;

  @override
  void initState() {
    super.initState();
    _nav = TaskyNav(
      goTab: (i) => setState(() => _tab = i),
      openTool: (id) => openToolPage(context, toolPageFor(id)),
      askAssistant: (prefill) {
        setState(() => _tab = 2);
        // let the tab switch settle before prefilling
        Future.delayed(const Duration(milliseconds: 80), () {
          _assistantKey.currentState?.prefill(prefill);
        });
      },
    );
    final store = context.read<TaskyStore>();
    _storeListener = () {
      _rescheduleTimer?.cancel();
      _rescheduleTimer = Timer(
          const Duration(seconds: 2), () => NotifyService.reschedule(store));
    };
    store.addListener(_storeListener);
    // initial schedule
    NotifyService.reschedule(store);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeExplainNotif());
  }

  Future<void> _maybeExplainNotif() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notifExplained') ?? false) return;
    await prefs.setBool('notifExplained', true);
    if (!mounted) return;
    final store = context.read<TaskyStore>();
    final allow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Stay on top of things? 🔔'),
        content: const Text(
            'Tasky can notify you about upcoming tasks, overdue items, calendar events, and recurring reminders. You can change this anytime in Profile → Notifications.'),
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
      store.notificationsEnabled = granted;
      await store.persist();
      await NotifyService.reschedule(store);
    } else {
      store.notificationsEnabled = false;
      await store.persist();
    }
  }

  @override
  void dispose() {
    _rescheduleTimer?.cancel();
    context.read<TaskyStore>().removeListener(_storeListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(nav: _nav),
          TasksScreen(nav: _nav),
          AssistantScreen(key: _assistantKey, nav: _nav),
          CalendarScreen(nav: _nav),
          ProfileScreen(nav: _nav),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(
                    t.brightness == Brightness.dark ? 0.4 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.check_circle_outline),
                activeIcon: Icon(Icons.check_circle),
                label: 'Tasks'),
            BottomNavigationBarItem(
                icon: Icon(Icons.auto_awesome_outlined),
                activeIcon: Icon(Icons.auto_awesome),
                label: 'Assistant'),
            BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month_outlined),
                activeIcon: Icon(Icons.calendar_month),
                label: 'Calendar'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
