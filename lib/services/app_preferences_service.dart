import "dart:convert";

import "package:flutter/foundation.dart";
import "package:hive_flutter/hive_flutter.dart";

import "../models/navigation_settings.dart";
import "../models/recent_location.dart";

/// * Lightweight app preferences stored locally using Hive.
/// *
/// * This is used for user-customizable UX (navigation avatar, speed alerts, etc.)
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

  // ============================================================
  // * COMMUTE MODE SETTINGS
  // ============================================================

  static const String _keyCommuteSettings = "commute_settings_v1";
  static const String _keyRecentCommuteDestinations = "recent_commute_destinations_v1";

  /// * Load commute settings
  Future<Map<String, dynamic>> loadCommuteSettings() async {
    final box = await _ensureBox();
    final raw = box.get(_keyCommuteSettings);
    if (raw == null || raw is! String || raw.trim().isEmpty) {
      return {
        "alarmDistanceMeters": 500,
        "useTimeBackupAlarm": true,
        "backupAlarmMinutes": 5,
        "vibrateOnAlarm": true,
        "playSoundOnAlarm": true,
      };
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return {
        "alarmDistanceMeters": 500,
        "useTimeBackupAlarm": true,
        "backupAlarmMinutes": 5,
        "vibrateOnAlarm": true,
        "playSoundOnAlarm": true,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint("❌ [AppPreferencesService] Failed to parse commute settings: $e");
      }
      return {
        "alarmDistanceMeters": 500,
        "useTimeBackupAlarm": true,
        "backupAlarmMinutes": 5,
        "vibrateOnAlarm": true,
        "playSoundOnAlarm": true,
      };
    }
  }

  /// * Save commute settings
  Future<void> saveCommuteSettings(Map<String, dynamic> settings) async {
    final box = await _ensureBox();
    final encoded = jsonEncode(settings);
    await box.put(_keyCommuteSettings, encoded);
  }

  /// * Load recent commute destinations
  Future<List<Map<String, dynamic>>> loadRecentCommuteDestinations() async {
    final box = await _ensureBox();
    final raw = box.get(_keyRecentCommuteDestinations);
    if (raw == null) return [];

    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .take(10)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint("❌ [AppPreferencesService] Failed to parse commute destinations: $e");
      }
      return [];
    }
  }

  /// * Add a recent commute destination
  Future<List<Map<String, dynamic>>> addRecentCommuteDestination({
    required String name,
    required double latitude,
    required double longitude,
  }) async {
    final box = await _ensureBox();
    
    final incoming = {
      "name": name.trim().isEmpty ? "Location" : name.trim(),
      "lat": latitude,
      "lng": longitude,
      "updatedAt": DateTime.now().toIso8601String(),
    };

    final existing = await loadRecentCommuteDestinations();
    
    // * Remove duplicate by coordinates
    final filtered = existing.where((item) {
      final lat = item["lat"] as double?;
      final lng = item["lng"] as double?;
      if (lat == null || lng == null) return true;
      return (lat - latitude).abs() > 0.0001 || (lng - longitude).abs() > 0.0001;
    }).toList();

    final merged = <Map<String, dynamic>>[incoming, ...filtered].take(10).toList();

    final encoded = jsonEncode(merged);
    await box.put(_keyRecentCommuteDestinations, encoded);
    return merged;
  }

  // ============================================================
  // * MUSIC CONTROL SETTINGS
  // ============================================================

  static const String _keyMusicControlEnabled = "music_control_enabled";
  static const String _keyDefaultMusicAppId = "default_music_app_id_v1";

  /// * Get music control enabled preference
  Future<bool> getMusicControlEnabled() async {
    final box = await _ensureBox();
    final value = box.get(_keyMusicControlEnabled);
    return value == true;
  }

  /// * Set music control enabled preference
  Future<void> setMusicControlEnabled(bool enabled) async {
    final box = await _ensureBox();
    await box.put(_keyMusicControlEnabled, enabled);
  }

  /// * Get the user's default music app id (e.g., "spotify")
  Future<String?> getDefaultMusicAppId() async {
    final box = await _ensureBox();
    final value = box.get(_keyDefaultMusicAppId);
    if (value is! String) return null;

    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  /// * Set the user's default music app id (set to `null` to clear)
  Future<void> setDefaultMusicAppId(String? appId) async {
    final box = await _ensureBox();
    final normalized = appId?.trim().toLowerCase();

    if (normalized == null || normalized.isEmpty) {
      await box.delete(_keyDefaultMusicAppId);
      return;
    }

    await box.put(_keyDefaultMusicAppId, normalized);
  }

  // ============================================================
  // * FUEL COMMUNITY SETTINGS (ANONYMOUS DEVICE ID + RATE LIMITING)
  // ============================================================

  static const String _keyFuelDeviceId = "fuel_device_id_v1";
  static const String _keyFuelSubmissionLog = "fuel_submission_log_v1";

  /// * Get or create persistent anonymous device ID for fuel submissions.
  Future<String> getFuelDeviceId() async {
    final box = await _ensureBox();
    final existing = box.get(_keyFuelDeviceId);
    
    if (existing is String && existing.trim().isNotEmpty) {
      return existing.trim();
    }

    // * Generate new device ID (simple timestamp + random suffix)
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = (now % 100000).toString().padLeft(5, '0');
    final deviceId = "device_$now$random";
    
    await box.put(_keyFuelDeviceId, deviceId);
    return deviceId;
  }

  /// * Record a fuel submission locally for rate-limit UX feedback.
  /// *
  /// * This provides immediate feedback before server validation.
  /// * Structure: { stationId: { fuelType: [timestamp1, timestamp2, ...] } }
  Future<void> recordFuelSubmission({
    required String stationId,
    required String fuelType,
  }) async {
    final box = await _ensureBox();
    final now = DateTime.now();
    
    // * Load existing log
    final raw = box.get(_keyFuelSubmissionLog);
    Map<String, dynamic> log = {};
    
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          log = decoded;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint("❌ [AppPreferencesService] Failed to parse fuel log: $e");
        }
      }
    }

    // * Add new submission timestamp
    final stationData = log[stationId] as Map<String, dynamic>? ?? {};
    final timestamps = stationData[fuelType] as List? ?? [];
    timestamps.add(now.toIso8601String());
    stationData[fuelType] = timestamps;
    log[stationId] = stationData;

    // * Clean up old entries (keep last 20 per station)
    for (final stKey in log.keys.toList()) {
      final stData = log[stKey] as Map<String, dynamic>? ?? {};
      for (final ftKey in stData.keys.toList()) {
        final tsList = stData[ftKey] as List? ?? [];
        if (tsList.length > 20) {
          stData[ftKey] = tsList.sublist(tsList.length - 20);
        }
      }
      log[stKey] = stData;
    }

    // * Save back
    final encoded = jsonEncode(log);
    await box.put(_keyFuelSubmissionLog, encoded);
  }

  /// * Check if local rate limit allows submission (client-side mirror).
  /// *
  /// * Returns true if submission is allowed, false if rate-limited.
  /// * Rules: max 5 submissions per fuel type in 10 minutes.
  Future<bool> checkFuelRateLimit({
    required String stationId,
    required String fuelType,
  }) async {
    final box = await _ensureBox();
    final raw = box.get(_keyFuelSubmissionLog);
    
    if (raw == null || raw is! String || raw.trim().isEmpty) {
      return true; // * No log yet, allow
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return true;

      final stationData = decoded[stationId] as Map<String, dynamic>?;
      if (stationData == null) return true;

      final timestamps = stationData[fuelType] as List?;
      if (timestamps == null || timestamps.isEmpty) return true;

      // * Count submissions in last 10 minutes
      final cutoff = DateTime.now().subtract(const Duration(minutes: 10));
      final recentCount = timestamps.where((ts) {
        if (ts is! String) return false;
        final dt = DateTime.tryParse(ts);
        if (dt == null) return false;
        return dt.isAfter(cutoff);
      }).length;

      return recentCount < 5;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("❌ [AppPreferencesService] Failed to check rate limit: $e");
      }
      return true; // * Allow on error
    }
  }

  /// * Check if station/fuel cooldown allows submission (15 minute cooldown).
  /// *
  /// * Returns true if submission is allowed, false if still on cooldown.
  Future<bool> checkFuelCooldown({
    required String stationId,
    required String fuelType,
  }) async {
    final box = await _ensureBox();
    final raw = box.get(_keyFuelSubmissionLog);
    
    if (raw == null || raw is! String || raw.trim().isEmpty) {
      return true; // * No log yet, allow
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return true;

      final stationData = decoded[stationId] as Map<String, dynamic>?;
      if (stationData == null) return true;

      final timestamps = stationData[fuelType] as List?;
      if (timestamps == null || timestamps.isEmpty) return true;

      // * Get most recent timestamp
      final lastTsStr = timestamps.last as String?;
      if (lastTsStr == null) return true;

      final lastTs = DateTime.tryParse(lastTsStr);
      if (lastTs == null) return true;

      // * Check if 15 minutes have passed
      final now = DateTime.now();
      final diff = now.difference(lastTs);
      return diff.inMinutes >= 15;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("❌ [AppPreferencesService] Failed to check cooldown: $e");
      }
      return true; // * Allow on error
    }
  }

  /// * Clear fuel submission log (for testing or reset).
  Future<void> clearFuelSubmissionLog() async {
    final box = await _ensureBox();
    await box.delete(_keyFuelSubmissionLog);
  }
}

