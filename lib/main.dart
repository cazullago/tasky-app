import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'notify.dart';
import 'store.dart';

/// Crash-proof bootstrap (fixes the v1 "keeps stopping" bug):
/// - runZonedGuarded catches any stray async error.
/// - EVERY pre-runApp await is wrapped in try/catch.
/// - runApp is ALWAYS reached, even if notifications, timezone, or
///   storage init fails. Features degrade gracefully (silently off),
///   the app never dies on launch.
Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final store = await _safeBoot();
      runApp(TaskyRoot(store: store));
    },
    (Object error, StackTrace stack) {
      debugPrint('Tasky guarded zone error: $error');
    },
  );
}

Future<AppStore> _safeBoot() async {
  final store = AppStore();
  try {
    await store.load();
  } catch (e) {
    debugPrint('Tasky store.load failed (continuing): $e');
  }
  try {
    await store.loadUsers();
  } catch (e) {
    debugPrint('Tasky store.loadUsers failed (continuing): $e');
  }
  try {
    await NotifyService.init();
  } catch (e) {
    debugPrint('Tasky NotifyService.init failed (continuing): $e');
  }
  return store;
}
