import "dart:convert";

import "package:flutter/foundation.dart";
import "package:hive_flutter/hive_flutter.dart";

import "../models/navigation_settings.dart";

/// * Lightweight app preferences stored locally using Hive.
/// *
/// * This is used for user-customizable UX (Waze-style avatar, speed alerts, etc.)
/// * without requiring Supabase to be configured.
class AppPreferencesService {
  static const String _boxName = "app_preferences";
  static const String _keyNavigationSettings = "navigation_settings";

  static Box? _box;

  Future<Box> _ensureBox() async {
    if (_box != null) {
      return _box!;
    }

    try {
      await Hive.initFlutter();
    } catch (e) {
      // * Hive may already be initialized by another service (safe to ignore).
      if (kDebugMode) {
        debugPrint("ℹ️ [AppPreferencesService] Hive init skipped: $e");
      }
    }

    _box = await Hive.openBox(_boxName);
    return _box!;
  }

  Future<NavigationSettings> loadNavigationSettings() async {
    final box = await _ensureBox();
    final raw = box.get(_keyNavigationSettings);
    if (raw is! String || raw.trim().isEmpty) {
      return NavigationSettings.defaults();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return NavigationSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return NavigationSettings.fromJson(Map<String, dynamic>.from(decoded));
      }
      return NavigationSettings.defaults();
    } catch (e) {
      if (kDebugMode) {
        debugPrint("❌ [AppPreferencesService] Failed to parse settings: $e");
      }
      return NavigationSettings.defaults();
    }
  }

  Future<void> saveNavigationSettings(NavigationSettings settings) async {
    final box = await _ensureBox();
    final encoded = jsonEncode(settings.toJson());
    await box.put(_keyNavigationSettings, encoded);
  }
}

