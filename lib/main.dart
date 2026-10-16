import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'notify.dart';
import 'store.dart';

/// Crash-proof bootstrap.
///
/// ROOT CAUSE of the v2.0.0 "Tasky keeps stopping" on launch (found
/// 2026-10-17): MainActivity.kt declared `package com.example.tasky` while
/// the manifest (`android:name=".MainActivity"`, no `package` attribute)
/// plus `namespace = "com.tasky.app"` made Android look for
/// `com.tasky.app.MainActivity` -> ClassNotFoundException BEFORE any Dart
/// code ran. No Dart-side guard could ever catch it. Fixed by moving
/// MainActivity to package com.tasky.app.
///
/// This bootstrap additionally guarantees the app can NEVER die with a
/// silent "keeps stopping" again: every pre-runApp await is guarded, the
/// framework's error channel is routed into the same handler, and ANY init
/// failure renders [BootErrorApp] — an in-app screen showing the error
/// message, a stack snippet, and a Copy button — so a future screenshot
/// diagnoses itself.
bool _fatalShown = false;
bool _firstFrameDone = false;

/// Last-resort UI: replaces the whole app with the diagnosable error
/// screen. Deferred one microtask so we never re-enter the framework
/// mid-build.
void _showFatal(Object error, StackTrace stack) {
  if (_fatalShown) return;
  _fatalShown = true;
  Future.microtask(() {
    try {
      runApp(BootErrorApp(error: error, stack: stack));
    } catch (e) {
      debugPrint('Tasky: could not show fatal screen: $e');
    }
  });
}

/// Single funnel for zone errors AND Flutter framework errors.
/// Pre-first-frame failures escalate to the error screen; later (runtime)
/// framework errors are logged without nuking a running app.
void _onZoneError(Object error, StackTrace stack) {
  debugPrint('Tasky guarded zone error: $error');
  debugPrint('$stack');
  if (!_firstFrameDone) _showFatal(error, stack);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance
      .addPostFrameCallback((_) => _firstFrameDone = true);
  // Route build/layout/paint errors into the same guarded handler.
  FlutterError.onError = (FlutterErrorDetails details) {
    _onZoneError(
        details.exception, details.stack ?? StackTrace.empty);
  };
  await _start();
}

Future<void> _start() async {
  _fatalShown = false;
  AppStore? store;
  Object? bootError;
  StackTrace? bootStack;
  try {
    store = await _safeBoot();
  } catch (e, s) {
    bootError = e;
    bootStack = s;
  }
  if (bootError != null || store == null) {
    _showFatal(bootError ?? 'Unknown boot failure',
        bootStack ?? StackTrace.empty);
    return;
  }
  await runZonedGuarded<Future<void>>(() async {
    runApp(TaskyRoot(store: store!));
  }, _onZoneError);
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

/// Minimal app shown when boot fails. Deliberately self-contained: it does
/// NOT depend on AppStore, AppTheme, or any feature code, so it renders
/// even when those are the thing that broke.
class BootErrorApp extends StatelessWidget {
  final Object error;
  final StackTrace? stack;

  const BootErrorApp({super.key, required this.error, this.stack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      home: BootErrorScreen(error: error, stack: stack),
    );
  }
}

class BootErrorScreen extends StatelessWidget {
  final Object error;
  final StackTrace? stack;

  const BootErrorScreen({super.key, required this.error, this.stack});

  String get _stackSnippet {
    final lines = '$stack'.split('\n').where((l) => l.trim().isNotEmpty);
    final snippet = lines.take(14).join('\n');
    return snippet.isEmpty ? '(no stack trace captured)' : snippet;
  }

  String get _report =>
      'Tasky failed to start.\n\nERROR:\n$error\n\nSTACK:\n${stack ?? '(none)'}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1033),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.warning_amber_rounded,
                  size: 64, color: Color(0xFFFFB020)),
              const SizedBox(height: 16),
              const Text(
                "Tasky couldn't start",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Something broke during startup. Copy the details below '
                'and send them to support — they explain exactly what happened.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFFB9AEE0)),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      'ERROR:\n$error\n\nSTACK (snippet):\n$_stackSnippet',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFFFFD9D9),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: _report));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Error details copied to clipboard')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy details'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6C4CF1),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _firstFrameDone = false;
                        _start();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF6C4CF1)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
