/// * Status of required travel speed relative to legal regulations and feasibility.
enum RequiredSpeedStatus {
  /// * Speed is well within statutory and detected limits (<= 90%).
  safe,

  /// * Speed is near the maximum legal threshold (90% - 100%).
  moderate,

  /// * Speed strictly exceeds the legal speed limit (> 100%).
  exceedsLimit,

  /// * Target arrival time has passed or remaining moving time is impossible.
  unachievable,
}

/// * Calculation result for target arrival time and required travel speed.
class RequiredSpeedResult {
  final DateTime targetArrivalTime;
  final double remainingDistanceKm;
  final Duration availableTime;
  final Duration effectiveMovingTime;
  final double trafficDelayMinutes;
  final double pedestrianDelayMinutes;
  final double requiredSpeedKph;
  final int legalSpeedLimitKph;
  final RequiredSpeedStatus status;
  final String statusBadge;
  final String? warningMessage;
  final String? legalDisclaimer;

  const RequiredSpeedResult({
    required this.targetArrivalTime,
    required this.remainingDistanceKm,
    required this.availableTime,
    required this.effectiveMovingTime,
    required this.trafficDelayMinutes,
    required this.pedestrianDelayMinutes,
    required this.requiredSpeedKph,
    required this.legalSpeedLimitKph,
    required this.status,
    required this.statusBadge,
    this.warningMessage,
    this.legalDisclaimer,
  });

  bool get isExceedingLegalLimit =>
      status == RequiredSpeedStatus.exceedsLimit;

  bool get isUnachievable =>
      status == RequiredSpeedStatus.unachievable;

  bool get hasWarning => warningMessage != null && warningMessage!.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      "targetArrivalTime": targetArrivalTime.toIso8601String(),
      "remainingDistanceKm": remainingDistanceKm,
      "availableTimeSeconds": availableTime.inSeconds,
      "effectiveMovingTimeSeconds": effectiveMovingTime.inSeconds,
      "trafficDelayMinutes": trafficDelayMinutes,
      "pedestrianDelayMinutes": pedestrianDelayMinutes,
      "requiredSpeedKph": requiredSpeedKph,
      "legalSpeedLimitKph": legalSpeedLimitKph,
      "status": status.name,
      "statusBadge": statusBadge,
      "warningMessage": warningMessage,
      "legalDisclaimer": legalDisclaimer,
    };
  }

  factory RequiredSpeedResult.fromJson(Map<String, dynamic> json) {
    return RequiredSpeedResult(
      targetArrivalTime:
          DateTime.tryParse(json["targetArrivalTime"]?.toString() ?? "") ??
              DateTime.now(),
      remainingDistanceKm:
          (json["remainingDistanceKm"] as num?)?.toDouble() ?? 0.0,
      availableTime:
          Duration(seconds: (json["availableTimeSeconds"] as num?)?.toInt() ?? 0),
      effectiveMovingTime:
          Duration(seconds: (json["effectiveMovingTimeSeconds"] as num?)?.toInt() ?? 0),
      trafficDelayMinutes:
          (json["trafficDelayMinutes"] as num?)?.toDouble() ?? 0.0,
      pedestrianDelayMinutes:
          (json["pedestrianDelayMinutes"] as num?)?.toDouble() ?? 0.0,
      requiredSpeedKph:
          (json["requiredSpeedKph"] as num?)?.toDouble() ?? 0.0,
      legalSpeedLimitKph:
          (json["legalSpeedLimitKph"] as num?)?.toInt() ?? 60,
      status: RequiredSpeedStatus.values.firstWhere(
        (e) => e.name == json["status"],
        orElse: () => RequiredSpeedStatus.safe,
      ),
      statusBadge: json["statusBadge"]?.toString() ?? "On Schedule",
      warningMessage: json["warningMessage"]?.toString(),
      legalDisclaimer: json["legalDisclaimer"]?.toString(),
    );
  }
}
