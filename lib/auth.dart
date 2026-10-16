import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'store.dart';

/// Authentication for Tasky.
///
/// DEFAULT: local demo auth — accounts live only on this device, clearly
/// labeled "Demo mode" in the UI. No network, no Firebase config needed,
/// and it can never crash on missing google-services.json.
///
/// FIREBASE ENABLEMENT (documented in README, integration point below):
///   1. Add firebase_core + firebase_auth to pubspec (MIT/Apache/BSD-OK).
///   2. Add android/app/google-services.json (your Firebase project).
///   3. Enable Email/Password sign-in in the Firebase console.
///   4. Set [AuthService.useFirebase] = true and implement the three
///      methods marked FIREBASE below against FirebaseAuth.instance.
class AuthService extends ChangeNotifier {
  /// Flip to true after completing the README's Firebase steps.
  static const bool useFirebase = false;

  final AppStore store;
  final Uuid _uuid = const Uuid();

  AuthService(this.store);

  DemoUser? get currentUser => store.currentUser;
  bool get signedIn => currentUser != null;

  String _hash(String password, String salt) {
    final bytes = utf8.encode('$salt::$password');
    return sha256.convert(bytes).toString();
  }

  bool _validEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());

  /// Returns an error message, or null on success.
  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      // FIREBASE: replace this whole body with
      //   await FirebaseAuth.instance.createUserWithEmailAndPassword(...)
      // and persist the Firebase UID as the session.
      final cleanEmail = email.trim().toLowerCase();
      if (name.trim().isEmpty) return 'Please enter your name.';
      if (!_validEmail(cleanEmail)) return 'That email doesn\'t look right.';
      if (password.length < 6) {
        return 'Password needs at least 6 characters.';
      }
      if (store.users.any((u) => u.email == cleanEmail)) {
        return 'An account with this email already exists on this device.';
      }
      final salt = _uuid.v4();
      final user = DemoUser(
        id: _uuid.v4(),
        name: name.trim(),
        email: cleanEmail,
        passHash: _hash(password, salt),
        salt: salt,
        createdAt: DateTime.now(),
      );
      store.setUsers([...store.users, user]);
      await store.saveUsers();
      store.updateProfile(name: user.name, email: user.email);
      await store.setSession(user.id);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Tasky signUp failed: $e');
      return 'Something went wrong creating the account. Please try again.';
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // FIREBASE: replace this whole body with
      //   await FirebaseAuth.instance.signInWithEmailAndPassword(...)
      final cleanEmail = email.trim().toLowerCase();
      DemoUser? found;
      for (final u in store.users) {
        if (u.email == cleanEmail) found = u;
      }
      if (found == null) {
        return 'No demo account found with this email on this device.';
      }
      if (_hash(password, found.salt) != found.passHash) {
        return 'Wrong password. Try again.';
      }
      store.updateProfile(name: found.name, email: found.email);
      await store.setSession(found.id);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Tasky signIn failed: $e');
      return 'Something went wrong signing in. Please try again.';
    }
  }

  Future<void> signOut() async {
    try {
      // FIREBASE: also call FirebaseAuth.instance.signOut().
      await store.setSession(null);
    } catch (e) {
      debugPrint('Tasky signOut failed: $e');
    }
    notifyListeners();
  }
}
