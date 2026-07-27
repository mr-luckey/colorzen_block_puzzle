import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Play Store in-app update check (Android only).
abstract class UpdateService {
  /// Returns true when a newer version is available on Play Store.
  Future<bool> isUpdateAvailable();

  /// Starts an immediate Play Store update flow.
  Future<void> startUpdate();
}

class PlayUpdateService implements UpdateService {
  @override
  Future<bool> isUpdateAvailable() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final info = await InAppUpdate.checkForUpdate();
      return info.updateAvailability == UpdateAvailability.updateAvailable;
    } catch (_) {
      // Sideload / debug / Play services unavailable — skip quietly.
      return false;
    }
  }

  @override
  Future<void> startUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (_) {
      // User cancelled or update failed — ignore.
    }
  }
}
