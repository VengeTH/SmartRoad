import "package:uuid/uuid.dart";

/// * Type of route activity: searched vs initiated/started ride.
enum RouteActivityType {
  /// * User searched or calculated route without starting ride yet.
  searched,

  /// * User initiated navigation / started the ride.
  initiated,
}

extension RouteActivityTypeX on RouteActivityType {
  String get displayName {
    switch (this) {
      case RouteActivityType.searched:
        return "Searched Only";
      case RouteActivityType.initiated:
        return "Ride Initiated";
    }
  }

  String get value {
    switch (this) {
      case RouteActivityType.searched:
        return "searched";
      case RouteActivityType.initiated:
        return "initiated";
    }
  }

  static RouteActivityType fromValue(String? val) {
    if (val?.toLowerCase() == "initiated") {
      return RouteActivityType.initiated;
    }
    return RouteActivityType.searched;
  }
}

/// * Persistent activity log for route search and initiated ride.
class RouteActivityLog {
  final String id;
  final RouteActivityType type;
  final DateTime searchedAt;
  final DateTime? initiatedAt;
  final String originLabel;
  final String destinationLabel;
  final double originLat;
  final double originLon;
  final double destinationLat;
  final double destinationLon;
  final double distanceKm;
  final int estimatedDurationMinutes;
  final String mode;
  final DateTime? targetArrivalTime;
  final double? requiredSpeedKph;
  final int? legalSpeedLimitKph;
  final bool isExceedingLimit;

  const RouteActivityLog({
    required this.id,
    required this.type,
    required this.searchedAt,
    this.initiatedAt,
    required this.originLabel,
    required this.destinationLabel,
    required this.originLat,
    required this.originLon,
    required this.destinationLat,
    required this.destinationLon,
    required this.distanceKm,
    required this.estimatedDurationMinutes,
    required this.mode,
    this.targetArrivalTime,
    this.requiredSpeedKph,
    this.legalSpeedLimitKph,
    this.isExceedingLimit = false,
  });

  bool get isSearchedOnly => type == RouteActivityType.searched;
  bool get isRideInitiated => type == RouteActivityType.initiated;

  String get formattedDuration {
    if (estimatedDurationMinutes < 60) {
      return "$estimatedDurationMinutes min";
    }
    final hours = estimatedDurationMinutes ~/ 60;
    final mins = estimatedDurationMinutes % 60;
    return mins > 0 ? "${hours}h ${mins}m" : "${hours}h";
  }

  RouteActivityLog copyWith({
    String? id,
    RouteActivityType? type,
    DateTime? searchedAt,
    DateTime? initiatedAt,
    String? originLabel,
    String? destinationLabel,
    double? originLat,
    double? originLon,
    double? destinationLat,
    double? destinationLon,
    double? distanceKm,
    int? estimatedDurationMinutes,
    String? mode,
    DateTime? targetArrivalTime,
    double? requiredSpeedKph,
    int? legalSpeedLimitKph,
    bool? isExceedingLimit,
  }) {
    return RouteActivityLog(
      id: id ?? this.id,
      type: type ?? this.type,
      searchedAt: searchedAt ?? this.searchedAt,
      initiatedAt: initiatedAt ?? this.initiatedAt,
      originLabel: originLabel ?? this.originLabel,
      destinationLabel: destinationLabel ?? this.destinationLabel,
      originLat: originLat ?? this.originLat,
      originLon: originLon ?? this.originLon,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLon: destinationLon ?? this.destinationLon,
      distanceKm: distanceKm ?? this.distanceKm,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      mode: mode ?? this.mode,
      targetArrivalTime: targetArrivalTime ?? this.targetArrivalTime,
      requiredSpeedKph: requiredSpeedKph ?? this.requiredSpeedKph,
      legalSpeedLimitKph: legalSpeedLimitKph ?? this.legalSpeedLimitKph,
      isExceedingLimit: isExceedingLimit ?? this.isExceedingLimit,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "type": type.value,
      "searchedAtMs": searchedAt.millisecondsSinceEpoch,
      "initiatedAtMs": initiatedAt?.millisecondsSinceEpoch,
      "originLabel": originLabel,
      "destinationLabel": destinationLabel,
      "originLat": originLat,
      "originLon": originLon,
      "destinationLat": destinationLat,
      "destinationLon": destinationLon,
      "distanceKm": distanceKm,
      "estimatedDurationMinutes": estimatedDurationMinutes,
      "mode": mode,
      "targetArrivalTimeMs": targetArrivalTime?.millisecondsSinceEpoch,
      "requiredSpeedKph": requiredSpeedKph,
      "legalSpeedLimitKph": legalSpeedLimitKph,
      "isExceedingLimit": isExceedingLimit,
    };
  }

  factory RouteActivityLog.fromJson(Map<String, dynamic> json) {
    final searchedAtMs = (json["searchedAtMs"] as num?)?.toInt() ?? 0;
    final initiatedAtMs = (json["initiatedAtMs"] as num?)?.toInt();
    final targetArrivalTimeMs = (json["targetArrivalTimeMs"] as num?)?.toInt();

    return RouteActivityLog(
      id: json["id"]?.toString() ?? const Uuid().v4(),
      type: RouteActivityTypeX.fromValue(json["type"]?.toString()),
      searchedAt: DateTime.fromMillisecondsSinceEpoch(searchedAtMs),
      initiatedAt: initiatedAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(initiatedAtMs)
          : null,
      originLabel: json["originLabel"]?.toString() ?? "Origin",
      destinationLabel: json["destinationLabel"]?.toString() ?? "Destination",
      originLat: (json["originLat"] as num?)?.toDouble() ?? 0.0,
      originLon: (json["originLon"] as num?)?.toDouble() ?? 0.0,
      destinationLat: (json["destinationLat"] as num?)?.toDouble() ?? 0.0,
      destinationLon: (json["destinationLon"] as num?)?.toDouble() ?? 0.0,
      distanceKm: (json["distanceKm"] as num?)?.toDouble() ?? 0.0,
      estimatedDurationMinutes:
          (json["estimatedDurationMinutes"] as num?)?.toInt() ?? 0,
      mode: json["mode"]?.toString() ?? "car",
      targetArrivalTime: targetArrivalTimeMs != null
          ? DateTime.fromMillisecondsSinceEpoch(targetArrivalTimeMs)
          : null,
      requiredSpeedKph: (json["requiredSpeedKph"] as num?)?.toDouble(),
      legalSpeedLimitKph: (json["legalSpeedLimitKph"] as num?)?.toInt(),
      isExceedingLimit: json["isExceedingLimit"] == true,
    );
  }
}
