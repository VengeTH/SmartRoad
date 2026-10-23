import "dart:math" as math;

import "../models/required_speed_result.dart";
import "../services/speed_limit_service.dart";

/// * Service that computes required travel speed to meet a target arrival time,
/// * factoring in traffic delays, pedestrian lane delays/crossings, and legal speed limits.
class TargetSpeedService {
  static final TargetSpeedService _instance = TargetSpeedService._internal();
  factory TargetSpeedService() => _instance;
  TargetSpeedService._internal();

  /// * Statutory default speed limits in the Philippines (RA 4136 / Joint Memo Circular 2018-001).
  static const int defaultUrbanLimitKph = 60;
  static const int defaultTruckLimitKph = 50;
  static const int defaultPedestrianWalkKph = 6;
  static const int maxStatutoryExpresswayKph = 100;

  /// * Computes required speed and evaluates legal compliance.
  /// *
  /// * [distanceKm]: Remaining distance in kilometers.
  /// * [targetArrivalTime]: When the user needs or wants to arrive.
  /// * [now]: Current time (defaults to [DateTime.now()]).
  /// * [mode]: Vehicle/travel mode ('car', 'motorcycle_sub400', 'motorcycle_400plus', 'truck', 'pedestrian').
  /// * [currentSpeedLimit]: Active speed limit result from [SpeedLimitService] if available.
  /// * [baseEstimatedDuration]: Duration estimated by routing engine without custom speed.
  /// * [pedestrianCrossingsCount]: Number of pedestrian lanes / crosswalks along the route (optional).
  /// * [trafficDelayMinutes]: Additional traffic congestion delay (minutes).
  RequiredSpeedResult computeRequiredSpeed({
    required double distanceKm,
    required DateTime targetArrivalTime,
    DateTime? now,
    String mode = "car",
    SpeedLimitResult? currentSpeedLimit,
    Duration? baseEstimatedDuration,
    int? pedestrianCrossingsCount,
    double trafficDelayMinutes = 0.0,
  }) {
    final currentTime = now ?? DateTime.now();
    final totalAvailable = targetArrivalTime.difference(currentTime);

    final resolvedLegalLimit = _resolveLegalSpeedLimit(
      mode: mode,
      speedLimitResult: currentSpeedLimit,
    );

    // * Check if target time has already passed or distance is 0
    if (totalAvailable.isNegative || totalAvailable == Duration.zero) {
      return RequiredSpeedResult(
        targetArrivalTime: targetArrivalTime,
        remainingDistanceKm: distanceKm,
        availableTime: totalAvailable,
        effectiveMovingTime: Duration.zero,
        trafficDelayMinutes: trafficDelayMinutes,
        pedestrianDelayMinutes: 0.0,
        requiredSpeedKph: 0.0,
        legalSpeedLimitKph: resolvedLegalLimit,
        status: RequiredSpeedStatus.unachievable,
        statusBadge: "Past Target",
        warningMessage: "Target arrival time has already passed.",
        legalDisclaimer: "Prioritize road safety. Never speed to make up for lost time.",
      );
    }

    if (distanceKm <= 0.05) {
      return RequiredSpeedResult(
        targetArrivalTime: targetArrivalTime,
        remainingDistanceKm: distanceKm,
        availableTime: totalAvailable,
        effectiveMovingTime: totalAvailable,
        trafficDelayMinutes: 0.0,
        pedestrianDelayMinutes: 0.0,
        requiredSpeedKph: 0.0,
        legalSpeedLimitKph: resolvedLegalLimit,
        status: RequiredSpeedStatus.safe,
        statusBadge: "Arriving",
        warningMessage: null,
        legalDisclaimer: null,
      );
    }

    // * Estimate pedestrian lanes friction:
    // * In Philippine cities / towns, pedestrian lanes and crosswalks introduce
    // * deceleration, pedestrian-yield stops (~15-25 seconds per lane).
    // * If not explicitly provided, estimate ~1.5 pedestrian crossings per kilometer in urban trips.
    final crossings = pedestrianCrossingsCount ??
        (mode == "pedestrian" ? 0 : math.max(1, (distanceKm * 1.5).round()));
    // * Seconds spent yielding or stopping at pedestrian crossings
    final pedestrianDelaySeconds = (crossings * 18).clamp(0, 1800);
    final pedestrianDelayMins = pedestrianDelaySeconds / 60.0;

    // * Total delays from traffic and pedestrian lanes
    final totalDelaysSeconds =
        (trafficDelayMinutes * 60).round() + pedestrianDelaySeconds;

    // * Calculate net effective moving time
    final availableSeconds = totalAvailable.inSeconds;
    final movingSeconds = availableSeconds - totalDelaysSeconds;

    // * If moving time is practically zero or negative given traffic & pedestrian lanes
    if (movingSeconds <= 30) {
      return RequiredSpeedResult(
        targetArrivalTime: targetArrivalTime,
        remainingDistanceKm: distanceKm,
        availableTime: totalAvailable,
        effectiveMovingTime: Duration(seconds: math.max(0, movingSeconds)),
        trafficDelayMinutes: trafficDelayMinutes,
        pedestrianDelayMinutes: pedestrianDelayMins,
        requiredSpeedKph: (distanceKm / (math.max(1, availableSeconds) / 3600.0)),
        legalSpeedLimitKph: resolvedLegalLimit,
        status: RequiredSpeedStatus.unachievable,
        statusBadge: "Delayed",
        warningMessage:
            "Traffic and pedestrian lane stops make on-time arrival unachievable within legal limits.",
        legalDisclaimer:
            "Do not overspeed. Philippine traffic regulations penalize overspeeding regardless of target time.",
      );
    }

    // * Speed in km/h = distance in km / time in hours
    final movingHours = movingSeconds / 3600.0;
    final rawRequiredSpeed = distanceKm / movingHours;
    final requiredSpeedKph = double.parse(rawRequiredSpeed.toStringAsFixed(1));

    // * Check legal speed thresholds
    final isOverLimit = requiredSpeedKph > resolvedLegalLimit;
    final isNearLimit = requiredSpeedKph > (resolvedLegalLimit * 0.90);

    RequiredSpeedStatus status;
    String badge;
    String? warning;
    String? disclaimer;

    if (isOverLimit) {
      status = RequiredSpeedStatus.exceedsLimit;
      badge = "Exceeds Limit";
      warning =
          "⚠️ Required speed (${requiredSpeedKph.round()} km/h) exceeds the legal speed limit (${resolvedLegalLimit} km/h).";
      disclaimer =
          "LEGAL NOTICE: Obey Philippine traffic laws (RA 4136 / Local Ordinances). Arriving on time does not excuse overspeeding. Drive at or below the legal limit.";
    } else if (isNearLimit) {
      status = RequiredSpeedStatus.moderate;
      badge = "Near Limit";
      warning =
          "⚡ Required speed is close to the speed limit (${resolvedLegalLimit} km/h). Drive carefully.";
      disclaimer = "Maintain a safe following distance and observe pedestrian lanes.";
    } else {
      status = RequiredSpeedStatus.safe;
      badge = "On Schedule";
      warning = null;
      disclaimer = null;
    }

    return RequiredSpeedResult(
      targetArrivalTime: targetArrivalTime,
      remainingDistanceKm: distanceKm,
      availableTime: totalAvailable,
      effectiveMovingTime: Duration(seconds: movingSeconds),
      trafficDelayMinutes: trafficDelayMinutes,
      pedestrianDelayMinutes: pedestrianDelayMins,
      requiredSpeedKph: requiredSpeedKph,
      legalSpeedLimitKph: resolvedLegalLimit,
      status: status,
      statusBadge: badge,
      warningMessage: warning,
      legalDisclaimer: disclaimer,
    );
  }

  /// * Resolves the legal speed limit to apply based on highway segment or vehicle mode.
  int _resolveLegalSpeedLimit({
    required String mode,
    SpeedLimitResult? speedLimitResult,
  }) {
    if (mode == "pedestrian") {
      return defaultPedestrianWalkKph;
    }

    // * Use detected OSM or user-override speed limit if valid and positive
    final detectedLimit = speedLimitResult?.speedLimitKph;
    if (detectedLimit != null && detectedLimit > 0) {
      return detectedLimit;
    }

    // * Fallback to mode statutory guidelines in Philippines
    switch (mode) {
      case "truck":
        return defaultTruckLimitKph;
      case "motorcycle_sub400":
        return 60; // * Non-expressway roads
      case "motorcycle_400plus":
      case "car":
      default:
        return defaultUrbanLimitKph;
    }
  }
}
