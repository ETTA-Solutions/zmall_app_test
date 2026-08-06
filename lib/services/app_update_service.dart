import 'package:flutter/material.dart';
import 'package:zmall/services/core_services.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/widgets/app_update_dialog.dart';
import 'package:app_version_update/app_version_update.dart';
import 'package:app_version_update/data/models/app_version_result.dart';

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

  /// Checks app stores for a newer version in parallel with initialization.
  /// Silently ignored if it fails or times out — it is non-critical.
  static Future<void> checkVersionUpdate({
    required BuildContext context,
  }) async {
    try {
      // Block automatic store update if backend is forcing an update
      final isForceUpdate = await Service.readBool("ios_force_update") ?? false;
      final showBackendDialog =
          await Service.readBool("ios_update_dialog") ?? false;
      // debugPrint( "isForceUpdate $isForceUpdate\nshowBackendDialog $showBackendDialog",);
      if (isForceUpdate || showBackendDialog) {
        // Backend is already handling the update dialog → skip store dialog
        // debugPrint("isreturn => true");
        return;
      }

      final result = await AppVersionUpdate.checkForUpdates(
        appleId: apple_id,
        playStoreId: playstore_id,
      );

      if (result.canUpdate != true) return;

      Future.delayed(const Duration(milliseconds: 400), () {
        _showVersionUpdateDialog(result: result, context: context);
      });
    } catch (_) {
      // Version check is best-effort — never crash the app over it
    }
  }

  static Future<void> _showVersionUpdateDialog({
    required AppVersionResult result,
    required BuildContext context,
  }) async {
    await AppVersionUpdate.showAlertUpdate(
      appVersionResult: result,
      context: context,
      backgroundColor: Colors.white,
      title: 'Update Available',
      titleTextStyle: const TextStyle(
        color: kBlackColor,
        fontWeight: FontWeight.bold,
        fontSize: 20.0,
      ),
      content:
          'A new version of ZMall is available. Update now for the latest features and improvements.',
      contentTextStyle: const TextStyle(
        color: kBlackColor,
        fontWeight: FontWeight.w400,
        fontSize: 14.0,
      ),
      updateButtonText: 'UPDATE',
      cancelButtonText: 'LATER',
      updateButtonStyle: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(kSecondaryColor),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      cancelButtonStyle: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(Color(0xFFE0E0E0)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      updateTextStyle: const TextStyle(color: Colors.white),
      cancelTextStyle: const TextStyle(color: kBlackColor),
    );
  }
}
