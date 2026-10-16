import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'store.dart';
import 'theme.dart';

/// App root: provides [AppStore] + [AuthService], wires the theme,
/// and gates on the persisted demo-auth session (no re-login).
class TaskyRoot extends StatelessWidget {
  final AppStore store;

  const TaskyRoot({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppStore>.value(value: store),
        ChangeNotifierProvider<AuthService>(
          create: (ctx) => AuthService(ctx.read<AppStore>()),
        ),
      ],
      child: Consumer<AppStore>(
        builder: (context, store, _) => MaterialApp(
          title: 'Tasky',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: store.settings.themeModeValue,
          home: const AuthGate(),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    // Store not loaded yet -> splash. (load() runs before runApp, so this
    // is only a safety net.)
    if (!context.watch<AppStore>().loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return auth.signedIn ? const HomeScreen() : const AuthScreen();
  }
}
