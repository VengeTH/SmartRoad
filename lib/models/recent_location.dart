/// * Recent location entry stored locally for quick access in the map search UI.
class RecentLocation {
  final String label;
  final double latitude;
  final double longitude;
  final RecentLocationKind kind;
  final DateTime updatedAt;

  const RecentLocation({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.kind,
    required this.updatedAt,
  });

  /// * A stable key used for de-duplication in local storage.
  /// * Rounds lat/lon to keep the history consistent across minor coordinate drift.
  String dedupeKey({int precision = 5}) {
    final lat = latitude.toStringAsFixed(precision);
    final lon = longitude.toStringAsFixed(precision);
    return "${kind.value}:$lat,$lon";
  }

  Map<String, dynamic> toJson() {
    return {
      "label": label,
      "latitude": latitude,
      "longitude": longitude,
      "kind": kind.value,
      "updatedAtMs": updatedAt.millisecondsSinceEpoch,
    };
  }

  factory RecentLocation.fromJson(Map<String, dynamic> json) {
    final rawLabel = json["label"];
    final rawLat = json["latitude"];
    final rawLon = json["longitude"];
    final rawKind = json["kind"];
    final rawUpdatedAt = json["updatedAtMs"];

    final label = rawLabel is String ? rawLabel.trim() : "";
    final lat = rawLat is num ? rawLat.toDouble() : double.nan;
    final lon = rawLon is num ? rawLon.toDouble() : double.nan;
    final kind =
        rawKind is String ? RecentLocationKindX.fromValue(rawKind) : RecentLocationKind.search;
    final updatedAtMs =
        rawUpdatedAt is int ? rawUpdatedAt : (rawUpdatedAt is num ? rawUpdatedAt.toInt() : 0);

    return RecentLocation(
      label: label.isEmpty ? "Location" : label,
      latitude: lat.isFinite ? lat : 0,
      longitude: lon.isFinite ? lon : 0,
      kind: kind,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
    );
  }
}

enum RecentLocationKind {
  search,
  navigation,
}

extension RecentLocationKindX on RecentLocationKind {
  String get value {
    switch (this) {
      case RecentLocationKind.search:
        return "search";
      case RecentLocationKind.navigation:
        return "navigation";
    }
  }

  static RecentLocationKind fromValue(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == "navigation") {
      return RecentLocationKind.navigation;
    }
    return RecentLocationKind.search;
  }
}

