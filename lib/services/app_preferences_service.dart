import "dart:convert";

import "package:flutter/foundation.dart";
import "package:hive_flutter/hive_flutter.dart";

import "../models/navigation_settings.dart";
import "../models/recent_location.dart";

/// * Lightweight app preferences stored locally using Hive.
/// *
/// * This is used for user-customizable UX (Waze-style avatar, speed alerts, etc.)
/// * without requiring Supabase to be configured.
class AppPreferencesService {
  static const String _boxName = "app_preferences";
  static const String _keyNavigationSettings = "navigation_settings";
  static const String _keyRecentLocations = "recent_locations_v1";
  static const int _recentLocationsMaxItems = 10;

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

  Future<List<RecentLocation>> loadRecentLocations() async {
    final box = await _ensureBox();
    final raw = box.get(_keyRecentLocations);
    if (raw == null) return [];

    try {
      final decoded =
          raw is String ? jsonDecode(raw) : raw;
      if (decoded is! List) return [];

      final items = decoded
          .whereType<Map>()
          .map((item) => RecentLocation.fromJson(Map<String, dynamic>.from(item)))
          .where((item) =>
              item.label.trim().isNotEmpty &&
              item.latitude.isFinite &&
              item.longitude.isFinite &&
              (item.latitude != 0 || item.longitude != 0))
          .toList();

      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items.take(_recentLocationsMaxItems).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint("❌ [AppPreferencesService] Failed to parse recents: $e");
      }
      return [];
    }
  }

  Future<List<RecentLocation>> addRecentLocation({
    required String label,
    required double latitude,
    required double longitude,
    required RecentLocationKind kind,
  }) async {
    final box = await _ensureBox();
    final now = DateTime.now();

    final incoming = RecentLocation(
      label: label.trim().isEmpty ? "Location" : label.trim(),
      latitude: latitude,
      longitude: longitude,
      kind: kind,
      updatedAt: now,
    );

    final existing = await loadRecentLocations();
    final incomingKey = incoming.dedupeKey();

    final merged = <RecentLocation>[
      incoming,
      ...existing.where((item) => item.dedupeKey() != incomingKey),
    ].take(_recentLocationsMaxItems).toList();

    final encoded = jsonEncode(merged.map((e) => e.toJson()).toList());
    await box.put(_keyRecentLocations, encoded);
    return merged;
  }

  Future<void> clearRecentLocations() async {
    final box = await _ensureBox();
    await box.delete(_keyRecentLocations);
  }
}

