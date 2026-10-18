import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'notify.dart';
import 'store.dart';

/// Crash-proof bootstrap.
///
/// Crash history (2026-10-17):
/// 1. v2.0.0 "keeps stopping": MainActivity.kt declared
///    `package com.example.tasky` while the manifest
///    (`android:name=".MainActivity"`, no `package` attribute) plus
///    `namespace = "com.tasky.app"` made Android look for
///    `com.tasky.app.MainActivity` -> ClassNotFoundException BEFORE any
///    Dart code ran. Fixed by moving MainActivity to package com.tasky.app.
/// 2. v2.0.1 "Zone mismatch": `WidgetsFlutterBinding.ensureInitialized()`
///    ran in the root zone while `runApp()` ran inside runZonedGuarded's
///    zone -> BindingBase.debugCheckZone threw at runApp. Fixed below.
///
/// ZONE RULE (the whole point of this structure): the bindings, ALL
/// startup init, and EVERY runApp call must execute in ONE single zone.
/// Note runZonedGuarded's onError handler runs in the PARENT zone, so it
/// must NEVER call runApp/_showFatal (that would reintroduce the
/// mismatch). It only logs.
///
/// This bootstrap guarantees the app can NEVER die with a silent
/// "keeps stopping" again: every init failure renders [BootErrorApp] —
/// an in-app screen showing the error message, a stack snippet, and a
/// Copy button — so a future screenshot diagnoses itself.
bool _fatalShown = false;
bool _firstFrameDone = false;

/// Re-runs [_boot] from the error screen's Retry button. Invoked from a
/// widget callback, which executes in the guarded zone where the bindings
/// live, so boot re-executes in the SAME zone. (Wrapping Retry in a fresh
/// runZonedGuarded would recreate the zone mismatch.)
Future<void> Function()? _retryBoot;

/// Shows the self-diagnosing error screen. MUST only be called from within
/// the guarded zone (boot try/catch, FlutterError.onError) — never from the
/// zone's onError handler, which runs in the parent zone.
void _showFatal(Object error, StackTrace stack) {
  if (_fatalShown) return;
  _fatalShown = true;
  // The microtask inherits the caller's zone (the guarded zone), so runApp
  // here stays in the same zone as the bindings. Deferred one microtask so
  // we never re-enter the framework mid-build.
  Future.microtask(() {
    try {
      runApp(BootErrorApp(error: error, stack: stack));
    } catch (e) {
      debugPrint('Tasky: could not show fatal screen: $e');
    }
  });
}

void main() {
  runZonedGuarded(() async {
    // ONE zone for: bindings init, all startup, every runApp call.
    WidgetsFlutterBinding.ensureInitialized();

    // Route build/layout/paint errors into the guarded handler. This
    // callback executes in the framework's zone (the guarded zone), so
    // _showFatal stays zone-consistent. Only escalate pre-first-frame;
    // never tear down a running app.
    FlutterError.onError = (FlutterErrorDetails details) {
      final Object e = details.exception;
      final StackTrace s = details.stack ?? StackTrace.empty;
      debugPrint('Tasky FlutterError: $e');
      debugPrint('$s');
      if (!_firstFrameDone) _showFatal(e, s);
    };

    _retryBoot = _boot;
    await _boot();
  }, (Object error, StackTrace stack) {
    // Runs in the PARENT zone of the guarded zone: report only, never
    // runApp/_showFatal here (wrong zone -> zone mismatch).
    debugPrint('Tasky guarded zone error: $error');
    debugPrint('$stack');
  });
}

/// One boot attempt. Always executed inside the guarded zone, so the
/// bindings init above and runApp below share the same zone.
Future<void> _boot() async {
  _fatalShown = false;
  _firstFrameDone = false;
  WidgetsBinding.instance
      .addPostFrameCallback((_) => _firstFrameDone = true);
  try {
    final store = await _safeBoot();
    runApp(TaskyRoot(store: store));
  } catch (e, s) {
    _showFatal(e, s);
  }
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
                        _retryBoot?.call();
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
