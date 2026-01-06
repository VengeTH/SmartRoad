import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/navigation_avatar_style.dart";
import "../models/navigation_settings.dart";
import "../services/app_preferences_service.dart";

/// * Navigation settings provider (local preferences).
final navigationSettingsProvider =
    StateNotifierProvider<NavigationSettingsNotifier, NavigationSettings>((ref) {
  return NavigationSettingsNotifier();
});

class NavigationSettingsNotifier extends StateNotifier<NavigationSettings> {
  final _prefs = AppPreferencesService();

  NavigationSettingsNotifier() : super(NavigationSettings.defaults()) {
    _load();
  }

  Future<void> _load() async {
    final loaded = await _prefs.loadNavigationSettings();
    state = loaded;
  }

  Future<void> _save(NavigationSettings next) async {
    state = next;
    await _prefs.saveNavigationSettings(next);
  }

  Future<void> setAvatarStyle(NavigationAvatarStyle style) async {
    await _save(state.copyWith(avatarStyle: style));
  }

  Future<void> setShowSpeedHud(bool value) async {
    await _save(state.copyWith(showSpeedHud: value));
  }

  Future<void> setOverspeedWarningsEnabled(bool value) async {
    await _save(state.copyWith(overspeedWarningsEnabled: value));
  }

  Future<void> setOverspeedToleranceKph(int value) async {
    await _save(state.copyWith(overspeedToleranceKph: value.clamp(0, 30)));
  }

  Future<void> setUseOsmSpeedLimits(bool value) async {
    await _save(state.copyWith(useOsmSpeedLimits: value));
  }

  Future<void> setDefaultSpeedLimitForHighway(String highway, int kph) async {
    final key = highway.trim().toLowerCase();
    if (key.isEmpty) return;
    final nextMap = Map<String, int>.from(state.defaultSpeedLimitsByHighway);
    nextMap[key] = kph.clamp(5, 200);
    await _save(state.copyWith(defaultSpeedLimitsByHighway: nextMap));
  }

  Future<void> resetDefaultSpeedLimits() async {
    await _save(
      state.copyWith(defaultSpeedLimitsByHighway: NavigationSettings.defaults().defaultSpeedLimitsByHighway),
    );
  }

  Future<void> setSpeedLimitOverrideForWay(int wayId, int kph) async {
    final nextMap = Map<int, int>.from(state.speedLimitOverridesByWayId);
    nextMap[wayId] = kph.clamp(5, 200);
    await _save(state.copyWith(speedLimitOverridesByWayId: nextMap));
  }

  Future<void> clearSpeedLimitOverrideForWay(int wayId) async {
    final nextMap = Map<int, int>.from(state.speedLimitOverridesByWayId);
    nextMap.remove(wayId);
    await _save(state.copyWith(speedLimitOverridesByWayId: nextMap));
  }

  Future<void> clearAllSpeedLimitOverrides() async {
    await _save(state.copyWith(speedLimitOverridesByWayId: const {}));
  }
}

