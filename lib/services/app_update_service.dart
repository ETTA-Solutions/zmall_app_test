import 'package:flutter/material.dart';
import 'package:zmall/services/core_services.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/widgets/app_update_dialog.dart';

class AppUpdateService {
  static bool _isUpdateDialogShown = false;

  /// Fetches app keys from the server, saves them locally,
  /// and optionally shows the update dialog if a new version is available.
  ///
  /// - [showDialogIfNeeded]: When `true` (default), checks version and shows
  ///   the update dialog if the remote version is newer.
  /// - [onMessageFlag]: Called when the server sends a `message_flag` notice
  ///   (e.g. service closure). Receives the message string.
  static Future<void> fetchAndCheck(
    BuildContext context, {
    bool showDialogIfNeeded = true,
    void Function(String message)? onMessageFlag,
  }) async {
    final data = await CoreServices.appKeys(context);
    if (data == null || data['success'] != true) return;

    // Save all keys to local storage
    _saveAppKeys(data);

    // Notify caller about message_flag (closure notices, etc.)
    if (data['message_flag'] == true && onMessageFlag != null) {
      onMessageFlag(data['message'] ?? '');
    }

    // Check version and show dialog if needed
    if (showDialogIfNeeded) {
      final remoteVersion = data['ios_user_app_version_code']?.toString();
      final showDialog = data['is_ios_user_app_open_update_dialog'] == true;
      final isForceUpdate = data['is_ios_user_app_force_update'] == true;

      if (remoteVersion != null &&
          showDialog &&
          !_isVersionUpToDate(remoteVersion) &&
          !_isUpdateDialogShown) {
        _isUpdateDialogShown = true;

        if (context.mounted) {
          AppUpdateDialog.show(
            context: context,
            isForceUpdate: isForceUpdate,
            onDismissed: () {
              _isUpdateDialogShown = false;
            },
          );
        }
      }
    }
  }

  /// Resets the dialog-shown guard. Call this if you need to allow
  /// the dialog to be shown again (e.g. after a hot restart).
  static void resetDialogGuard() {
    _isUpdateDialogShown = false;
  }

  static void _saveAppKeys(Map<String, dynamic> data) {
    Service.saveBool("is_closed", data['message_flag'] ?? false);
    Service.save("closed_message", data['message'] ?? '');
    Service.save("ios_app_version", data['ios_user_app_version_code'] ?? '');
    Service.saveBool(
      "ios_update_dialog",
      data['is_ios_user_app_open_update_dialog'] ?? false,
    );
    Service.saveBool(
      "ios_force_update",
      data['is_ios_user_app_force_update'] ?? false,
    );
    Service.save('app_close', data['app_close'] ?? '');
    Service.save('app_open', data['app_open'] ?? '');
  }

  /// Compares [remoteVersion] against [appVersion] using semantic versioning.
  /// Returns `true` if the current app version is up-to-date (>= remote).
  static bool _isVersionUpToDate(String remoteVersion) {
    final current = _parseVersion(appVersion);
    final remote = _parseVersion(remoteVersion);

    for (int i = 0; i < 3; i++) {
      if (current[i] < remote[i]) return false;
      if (current[i] > remote[i]) return true;
    }
    return true; // versions are equal
  }

  static List<int> _parseVersion(String version) {
    final parts = version.split('.');
    return List.generate(3, (i) {
      if (i < parts.length) return int.tryParse(parts[i]) ?? 0;
      return 0;
    });
  }
}
