import "navigation_avatar_style.dart";

/// * User navigation preferences (Waze/Google Maps-like).
class NavigationSettings {
  final NavigationAvatarStyle avatarStyle;

  /// * Show current speed during navigation.
  final bool showSpeedHud;

  /// * Enable overspeed warnings (visual + subtle haptics).
  final bool overspeedWarningsEnabled;

  /// * Overspeed tolerance in km/h before warning triggers.
  final int overspeedToleranceKph;

  /// * Use OpenStreetMap maxspeed tags (best-effort) when available.
  final bool useOsmSpeedLimits;

  /// * Default speed limits (km/h) by OSM `highway` tag.
  /// * Used as fallback when maxspeed is missing/invalid.
  final Map<String, int> defaultSpeedLimitsByHighway;

  /// * Manual overrides for a specific OSM way id.
  /// * Used when the user adjusts a speed limit for a road.
  final Map<int, int> speedLimitOverridesByWayId;

  const NavigationSettings({
    required this.avatarStyle,
    required this.showSpeedHud,
    required this.overspeedWarningsEnabled,
    required this.overspeedToleranceKph,
    required this.useOsmSpeedLimits,
    required this.defaultSpeedLimitsByHighway,
    required this.speedLimitOverridesByWayId,
  });

  factory NavigationSettings.defaults() {
    return NavigationSettings(
      avatarStyle: NavigationAvatarStyle.arrow,
      showSpeedHud: true,
      overspeedWarningsEnabled: true,
      overspeedToleranceKph: 5,
      useOsmSpeedLimits: true,
      defaultSpeedLimitsByHighway: const {
        // * Conservative defaults (PH-oriented). Users/admin can adjust these.
        "motorway": 100,
        "trunk": 80,
        "primary": 60,
        "secondary": 50,
        "tertiary": 40,
        "unclassified": 40,
        "residential": 30,
        "service": 20,
        "living_street": 15,
      },
      speedLimitOverridesByWayId: const {},
    );
  }

  NavigationSettings copyWith({
    NavigationAvatarStyle? avatarStyle,
    bool? showSpeedHud,
    bool? overspeedWarningsEnabled,
    int? overspeedToleranceKph,
    bool? useOsmSpeedLimits,
    Map<String, int>? defaultSpeedLimitsByHighway,
    Map<int, int>? speedLimitOverridesByWayId,
  }) {
    return NavigationSettings(
      avatarStyle: avatarStyle ?? this.avatarStyle,
      showSpeedHud: showSpeedHud ?? this.showSpeedHud,
      overspeedWarningsEnabled:
          overspeedWarningsEnabled ?? this.overspeedWarningsEnabled,
      overspeedToleranceKph: overspeedToleranceKph ?? this.overspeedToleranceKph,
      useOsmSpeedLimits: useOsmSpeedLimits ?? this.useOsmSpeedLimits,
      defaultSpeedLimitsByHighway:
          defaultSpeedLimitsByHighway ?? this.defaultSpeedLimitsByHighway,
      speedLimitOverridesByWayId:
          speedLimitOverridesByWayId ?? this.speedLimitOverridesByWayId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "avatarStyle": avatarStyle.id,
      "showSpeedHud": showSpeedHud,
      "overspeedWarningsEnabled": overspeedWarningsEnabled,
      "overspeedToleranceKph": overspeedToleranceKph,
      "useOsmSpeedLimits": useOsmSpeedLimits,
      "defaultSpeedLimitsByHighway": defaultSpeedLimitsByHighway,
      "speedLimitOverridesByWayId": speedLimitOverridesByWayId.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    };
  }

  factory NavigationSettings.fromJson(Map<String, dynamic> json) {
    final avatar = NavigationAvatarStyleX.fromId(
      json["avatarStyle"]?.toString(),
    );

    final showSpeedHud = json["showSpeedHud"] is bool ? json["showSpeedHud"] as bool : true;
    final overspeedWarningsEnabled =
        json["overspeedWarningsEnabled"] is bool
            ? json["overspeedWarningsEnabled"] as bool
            : true;

    final overspeedToleranceRaw = json["overspeedToleranceKph"];
    final overspeedToleranceKph = overspeedToleranceRaw is int
        ? overspeedToleranceRaw
        : (overspeedToleranceRaw is num ? overspeedToleranceRaw.toInt() : 5);

    final useOsmSpeedLimits = json["useOsmSpeedLimits"] is bool
        ? json["useOsmSpeedLimits"] as bool
        : true;

    final defaultSpeedLimitsByHighway = <String, int>{};
    final highwayJson = json["defaultSpeedLimitsByHighway"];
    if (highwayJson is Map) {
      for (final entry in highwayJson.entries) {
        final key = entry.key?.toString();
        final value = entry.value;
        if (key == null || key.trim().isEmpty) continue;
        if (value is int) {
          defaultSpeedLimitsByHighway[key] = value;
        } else if (value is num) {
          defaultSpeedLimitsByHighway[key] = value.toInt();
        }
      }
    }

    final speedLimitOverridesByWayId = <int, int>{};
    final overridesJson = json["speedLimitOverridesByWayId"];
    if (overridesJson is Map) {
      for (final entry in overridesJson.entries) {
        final key = int.tryParse(entry.key.toString());
        final value = entry.value;
        if (key == null) continue;
        if (value is int) {
          speedLimitOverridesByWayId[key] = value;
        } else if (value is num) {
          speedLimitOverridesByWayId[key] = value.toInt();
        }
      }
    }

    final defaults = NavigationSettings.defaults();
    return defaults.copyWith(
      avatarStyle: avatar,
      showSpeedHud: showSpeedHud,
      overspeedWarningsEnabled: overspeedWarningsEnabled,
      overspeedToleranceKph: overspeedToleranceKph.clamp(0, 30),
      useOsmSpeedLimits: useOsmSpeedLimits,
      defaultSpeedLimitsByHighway: defaultSpeedLimitsByHighway.isNotEmpty
          ? defaultSpeedLimitsByHighway
          : defaults.defaultSpeedLimitsByHighway,
      speedLimitOverridesByWayId: speedLimitOverridesByWayId,
    );
  }
}

