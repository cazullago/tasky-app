import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Permissions are requested AT THE POINT OF NEED, and only after a
/// plain-language rationale dialog explains WHY. No permission is requested
/// speculatively at startup.
class PermissionService {
  /// Shows a rationale dialog first, then the system dialog.
  /// Returns true when the permission is granted.
  static Future<bool> requestWithRationale(
    BuildContext context, {
    required Permission permission,
    required String title,
    required String body,
  }) async {
    try {
      final current = await permission.status;
      if (current.isGranted) return true;

      if (!context.mounted) return false;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (proceed != true) return false;

      final result = await permission.request();
      if (result.isGranted) return true;

      if (result.isPermanentlyDenied && context.mounted) {
        final open = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Permission needed'),
            content: const Text(
                'It looks like this permission was turned off. You can enable it anytime in the app settings.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Open settings'),
              ),
            ],
          ),
        );
        if (open == true) {
          await openAppSettings();
        }
      }
      return false;
    } catch (e) {
      debugPrint('Tasky permission request failed: $e');
      return false;
    }
  }

  static Future<bool> ensureNotifications(BuildContext context) =>
      requestWithRationale(
        context,
        permission: Permission.notification,
        title: 'Allow reminders?',
        body:
            'Tasky sends you a gentle nudge when a reminder is due. Without this, reminders are saved but silent.',
      );

  static Future<bool> ensureMicrophone(BuildContext context) =>
      requestWithRationale(
        context,
        permission: Permission.microphone,
        title: 'Use your microphone?',
        body:
            'Tap the mic to dictate instead of typing. Your voice is only used to turn speech into text on this device.',
      );

  static Future<bool> ensureCamera(BuildContext context) =>
      requestWithRationale(
        context,
        permission: Permission.camera,
        title: 'Use your camera?',
        body:
            'Take a profile photo or snap your study notes. Photos stay on this device.',
      );

  /// Current status of every permission Tasky can use.
  static Future<Map<String, PermissionStatus>> statuses() async {
    final out = <String, PermissionStatus>{};
    try {
      out['Notifications'] = await Permission.notification.status;
      out['Microphone'] = await Permission.microphone.status;
      out['Camera'] = await Permission.camera.status;
    } catch (e) {
      debugPrint('Tasky permission statuses failed: $e');
    }
    return out;
  }

  static Future<void> openSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('Tasky openAppSettings failed: $e');
    }
  }
}
