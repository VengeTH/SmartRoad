import "dart:async";
import "dart:io";

import "package:android_intent_plus/android_intent.dart";
import "package:android_intent_plus/flag.dart";
import "package:flutter/foundation.dart";

import "../models/music_app.dart";
import "app_preferences_service.dart";

/// * Music App Launcher Service
/// *
/// * Provides a quick-access "open music app" experience:
/// * - Detect installed supported music apps on Android
/// * - Launch the selected app
/// * - Remember the user's default music app preference
class MusicAppLauncherService {
  static final MusicAppLauncherService _instance =
      MusicAppLauncherService._internal();

  factory MusicAppLauncherService() => _instance;

  MusicAppLauncherService._internal();

  final AppPreferencesService _prefs = AppPreferencesService();

  /// * Returns supported apps that are installed on the device.
  Future<List<MusicAppDescriptor>> getInstalledSupportedApps() async {
    if (!Platform.isAndroid) return const [];

    final installed = <MusicAppDescriptor>[];
    for (final app in MusicAppDescriptor.supported) {
      final isInstalled = await _canResolvePackage(app.androidPackageName);
      if (isInstalled) {
        installed.add(app);
      }
    }
    return installed;
  }

  /// * Loads the saved default music app id (if any).
  Future<String?> getDefaultMusicAppId() async {
    return await _prefs.getDefaultMusicAppId();
  }

  /// * Saves the default music app id (set to `null` to clear).
  Future<void> setDefaultMusicAppId(String? appId) async {
    await _prefs.setDefaultMusicAppId(appId);
  }

  /// * Resolves the default app descriptor from preferences.
  Future<MusicAppDescriptor?> getDefaultMusicApp() async {
    final id = await getDefaultMusicAppId();
    return MusicAppDescriptor.fromId(id);
  }

  /// * Resolves the default app only if it is installed.
  Future<MusicAppDescriptor?> getDefaultInstalledMusicApp() async {
    final app = await getDefaultMusicApp();
    if (app == null) return null;

    final isInstalled = await _canResolvePackage(app.androidPackageName);
    if (!isInstalled) return null;
    return app;
  }

  /// * Launches the given app (Android-only).
  Future<bool> openMusicApp(MusicAppDescriptor app) async {
    if (!Platform.isAndroid) return false;

    try {
      final intent = AndroidIntent(
        action: "android.intent.action.MAIN",
        category: "android.intent.category.LAUNCHER",
        package: app.androidPackageName,
        flags: const [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("❌ [MusicAppLauncherService] Failed to launch ${app.id}: $e");
      }
      return false;
    }
  }

  /// * Opens the Play Store page for the given app (best-effort).
  Future<bool> openPlayStoreForApp(MusicAppDescriptor app) async {
    if (!Platform.isAndroid) return false;

    try {
      final intent = AndroidIntent(
        action: "android.intent.action.VIEW",
        data: app.playStoreUri.toString(),
        flags: const [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          "❌ [MusicAppLauncherService] Failed to open Play Store for ${app.id}: $e",
        );
      }
      return false;
    }
  }

  /// * Opens a generic Play Store search for music apps.
  Future<bool> openPlayStoreSearch() async {
    if (!Platform.isAndroid) return false;

    const searchUrl =
        "https://play.google.com/store/search?q=music%20player&c=apps";

    try {
      final intent = const AndroidIntent(
        action: "android.intent.action.VIEW",
        data: searchUrl,
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("❌ [MusicAppLauncherService] Play Store search failed: $e");
      }
      return false;
    }
  }

  Future<bool> _canResolvePackage(String packageName) async {
    try {
      final intent = AndroidIntent(
        action: "android.intent.action.MAIN",
        category: "android.intent.category.LAUNCHER",
        package: packageName,
      );
      final canResolve = await intent.canResolveActivity();
      return canResolve == true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          "❌ [MusicAppLauncherService] canResolveActivity failed for $packageName: $e",
        );
      }
      return false;
    }
  }
}

