import "../config/commute_fare_reference.dart";
import "../models/commute_guide_data.dart";
import "../models/commute_state.dart";
import "commute_ai_assistant_service.dart";
import "planner_local.dart";
import "planner_service.dart";
import "transit_stop_service.dart";

/// * Long-distance threshold in km; beyond this, heuristic avoids claiming direct jeepney.
const double kLongDistanceKm = 25.0;
const Duration _plannerTimeout = Duration(seconds: 3);
const Duration _stopLookupTimeout = Duration(seconds: 2);
const Duration _aiTimeout = Duration(seconds: 5);

/// * Builds structured commute guide from GTFS itinerary or heuristic (nearest stop + vehicle/distance).
/// * Deterministic only; AI fallback is gated by [CommuteGuideData.qualityHigh].
class CommuteGuideService {
  CommuteGuideService._();

  static final CommuteGuideService _instance = CommuteGuideService._();
  static CommuteGuideService get instance => _instance;

  /// * Builds guide for [state]. Reuses [state.transitItinerary] when present; otherwise fetches plan or heuristic.
  Future<CommuteGuideData> buildGuide(CommuteState state) async {
    final distanceMeters = state.distanceToDestinationMeters ?? state.initialDistanceMeters ?? 0;
    final distanceKm = distanceMeters / 1000.0;
    final vehicle = state.settings.vehicleType;
    final hasFare = CommuteFareReference.hasFareEstimate(vehicle);
    final start = state.currentPosition ?? state.startPosition;
    final dest = state.destination;
    final isPt = vehicle == VehicleType.jeepney ||
        vehicle == VehicleType.bus ||
        vehicle == VehicleType.tricycle;
    final isLongDistance = distanceKm >= kLongDistanceKm && isPt;

    // * Reuse stored transit itinerary from state so we do not replan on every refresh.
    final stored = state.transitItinerary;
    if (stored is PlannerItinerary) {
      return _fromGtfsItinerary(
        stored,
        destinationName: state.destinationName,
      );
    }

    if (start != null && dest != null && !isLongDistance) {
      try {
        final planResult = await PlannerService.instance
            .plan(
              fromLat: start.latitude,
              fromLon: start.longitude,
              toLat: dest.latitude,
              toLon: dest.longitude,
              datetime: DateTime.now(),
            )
            .timeout(_plannerTimeout);
        if (planResult.hasItineraries &&
            planResult.itineraries != null &&
            planResult.itineraries!.isNotEmpty) {
          return _fromGtfsItinerary(
            planResult.itineraries!.first,
            destinationName: state.destinationName,
          );
        }
      } catch (_) {
        // * Keep guide responsive when local transit planning is slow.
      }
    }

    TransitStopInfo? nearestStop;
    if (isPt && start != null) {
      try {
        nearestStop = await TransitStopService.instance
            .getNearestTransitStop(start)
            .timeout(_stopLookupTimeout);
      } catch (_) {
        nearestStop = null;
      }
    }

    final guide = _fromHeuristic(
      state: state,
      distanceKm: distanceKm,
      vehicle: vehicle,
      hasFare: hasFare,
      isPt: isPt,
      isLongDistance: isLongDistance,
      nearestStop: nearestStop,
    );

    if (guide.qualityHigh) return guide;

    CommuteGuideAugmentation? aug;
    try {
      aug = await CommuteAiAssistantService.instance
          .getGuideAugmentation(
            destinationName: state.destinationName ?? "destination",
            vehicleType: vehicle,
            distanceKm: distanceKm,
            currentWhereToBoard: guide.whereToBoard,
            currentWhatToTake: guide.whatToTake,
            currentNotes: guide.notes,
            originLat: start?.latitude,
            originLon: start?.longitude,
            destinationLat: dest?.latitude,
            destinationLon: dest?.longitude,
          )
          .timeout(_aiTimeout);
    } catch (_) {
      aug = null;
    }
    if (aug == null || aug.isEmpty) return guide;

    return CommuteGuideData(
      whereToBoard: aug.whereToBoard ?? guide.whereToBoard,
      whatToTake: aug.whatToTake ?? guide.whatToTake,
      estimatedFareText: guide.estimatedFareText,
      distanceAndTime: guide.distanceAndTime,
      notes: aug.notes ?? guide.notes,
      isFromGtfs: false,
      qualityHigh: false,
    );
  }

  CommuteGuideData _fromGtfsItinerary(
    PlannerItinerary itinerary, {
    String? destinationName,
  }) {
    final transitLegs = itinerary.legs.where((l) => l.mode == "transit").toList();
    final firstTransitLeg = transitLegs.isEmpty ? null : transitLegs.first;
    final walkLegs = itinerary.legs.where((l) => l.mode == "walk").toList();
    final firstWalkLeg = walkLegs.isEmpty ? null : walkLegs.first;
    final lastTransitLeg = transitLegs.isEmpty ? null : transitLegs.last;
    final boardWalkM = firstWalkLeg?.distanceM ?? 0.0;
    final totalWalkM = itinerary.totalWalkM;
    final totalTime = itinerary.totalTimeMin;
    final destName = destinationName?.trim().isNotEmpty == true
        ? destinationName!.trim()
        : "your destination";

    final whereToBoard = _formatWhereToBoardFromGtfs(
      firstTransitLeg: firstTransitLeg,
      lastTransitLeg: lastTransitLeg,
      boardWalkM: boardWalkM,
      destinationName: destName,
    );

    final whatToTake = _formatWhatToTakeFromGtfs(
      transitLegs: transitLegs,
      boardWalkM: boardWalkM,
      destinationName: destName,
    );

    final fare = itinerary.fareEstimatePhp;
    final minFare = (fare * 0.9).floor().clamp(1.0, fare);
    final maxFare = (fare * 1.15).ceil().clamp(fare, 9999.0);
    final estimatedFareText = minFare >= maxFare
        ? "~₱${fare.toStringAsFixed(0)}. Fares may vary."
        : "~₱${minFare.toStringAsFixed(0)}–₱${maxFare.toStringAsFixed(0)}. Fares may vary.";

    final distanceAndTime = "~$totalTime min total, ~${(totalWalkM / 1000).toStringAsFixed(1)} km walk.";

    final notes = _gtfsNotes(itinerary, boardWalkM: boardWalkM);

    return CommuteGuideData(
      whereToBoard: whereToBoard,
      whatToTake: whatToTake,
      estimatedFareText: estimatedFareText,
      distanceAndTime: distanceAndTime,
      notes: notes,
      isFromGtfs: true,
      qualityHigh: true,
    );
  }

  String _formatTransitLegs(List<PlannerLeg> transitLegs) {
    if (transitLegs.isEmpty) return "Transit";
    final parts = <String>[];
    for (final leg in transitLegs) {
      final raw = leg.vehicle ?? "Transit";
      final label = _readableRouteLabel(raw);
      if (transitLegs.length == 1) {
        return label;
      }
      parts.add("$label → ${leg.endName}");
    }
    return parts.join("; then ");
  }

  String _formatWhereToBoardFromGtfs({
    required PlannerLeg? firstTransitLeg,
    required PlannerLeg? lastTransitLeg,
    required double boardWalkM,
    required String destinationName,
  }) {
    if (firstTransitLeg == null) {
      return "No exact boarding point found. Ask at the nearest terminal for a ride to $destinationName.";
    }
    final boardSpot = firstTransitLeg.startName;
    final routeLabel = _compactVehicleName(firstTransitLeg.vehicle);
    final finalDrop = lastTransitLeg?.endName ?? destinationName;
    final walkPrefix = boardWalkM >= 120
        ? "Walk to $boardSpot (~${boardWalkM.round()} m), "
        : "Board at $boardSpot, ";
    return "${walkPrefix}ride $routeLabel bound for ${_formatBoardingTarget(finalDrop)}. Alight near $destinationName.";
  }

  String _formatWhatToTakeFromGtfs({
    required List<PlannerLeg> transitLegs,
    required double boardWalkM,
    required String destinationName,
  }) {
    if (transitLegs.isEmpty) {
      return "No transit leg detected. Walk or use nearby local transport to reach $destinationName.";
    }
    final steps = <String>[];
    if (boardWalkM >= 500) {
      steps.add("Tricycle (optional) to ${transitLegs.first.startName}");
    }
    for (final leg in transitLegs) {
      final routeLabel = _compactVehicleName(leg.vehicle);
      steps.add("$routeLabel to ${_formatBoardingTarget(leg.endName)}");
    }
    return steps.join(", then ");
  }

  String _formatBoardingTarget(String name) {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return "your stop";
    return cleaned;
  }

  String _compactVehicleName(String? vehicle) {
    final raw = _readableRouteLabel(vehicle ?? "Transit");
    final lower = raw.toLowerCase();
    if (lower.contains("jeep")) return "jeepney ($raw)";
    if (lower.contains("bus")) return "bus ($raw)";
    if (lower.contains("tric") || lower.contains("rickshaw")) {
      return "tricycle ($raw)";
    }
    return raw;
  }

  /// * Avoid raw trip_id in user-facing text; use a short readable label.
  String _readableRouteLabel(String vehicle) {
    if (vehicle.isEmpty) return "Transit";
    if (vehicle.length > 30 && !vehicle.contains(" ")) return "Route";
    return vehicle;
  }

  String _gtfsNotes(PlannerItinerary itinerary, {required double boardWalkM}) {
    final parts = <String>["Fares may vary. Have exact change when possible."];
    if (boardWalkM >= 300) {
      parts.add(" You may walk to save money if the weather and road conditions are safe.");
    }
    if (itinerary.transfers > 0) {
      parts.insert(0, "${itinerary.transfers} transfer(s). ");
    }
    final hasLowConfidence = itinerary.legs.any((l) => l.confidence == TransitConfidence.low);
    if (hasLowConfidence) {
      parts.add(" Route data may be incomplete.");
    }
    return parts.join("");
  }

  CommuteGuideData _fromHeuristic({
    required CommuteState state,
    required double distanceKm,
    required VehicleType vehicle,
    required bool hasFare,
    required bool isPt,
    required bool isLongDistance,
    TransitStopInfo? nearestStop,
  }) {
    final destName = state.destinationName ?? "your destination";

    final whereToBoard = _heuristicWhereToBoard(
      isPt: isPt,
      isLongDistance: isLongDistance,
      nearestStop: nearestStop,
      vehicle: vehicle,
      destName: destName,
    );

    final whatToTake = _heuristicWhatToTake(destName, distanceKm, vehicle, isLongDistance);

    final estimatedFareText = _heuristicFareText(distanceKm, vehicle, hasFare, isLongDistance);

    final distanceAndTime = "About ${state.formattedDistance} to go, ~${state.formattedEta}.";

    final notes = nearestStop != null
      ? "Fares may vary. Have exact change when possible. You may walk to ${nearestStop.name} to save money."
      : "Fares may vary. Have exact change when possible. You may walk to save money when the route is safe.";

    /// * Quality high only when non-PT or we have route-grounded evidence; a random nearby OSM stop is not high-confidence.
    final qualityHigh = !isPt || (nearestStop != null && !isLongDistance);

    return CommuteGuideData(
      whereToBoard: whereToBoard,
      whatToTake: whatToTake,
      estimatedFareText: estimatedFareText,
      distanceAndTime: distanceAndTime,
      notes: notes,
      isFromGtfs: false,
      qualityHigh: qualityHigh,
    );
  }

  String _heuristicWhereToBoard({
    required bool isPt,
    required bool isLongDistance,
    required TransitStopInfo? nearestStop,
    required VehicleType vehicle,
    required String destName,
  }) {
    if (!isPt) return "Start from your current location.";
    if (isLongDistance) {
      if (nearestStop != null) {
        return "Walk to ${nearestStop.name} (~${nearestStop.distanceMeters.round()} m), then ride to a major terminal for a transfer toward $destName.";
      }
      return "Start from your nearest major terminal, then transfer toward $destName (long-distance route).";
    }
    if (nearestStop != null) {
      return "Walk to ${nearestStop.name} (~${nearestStop.distanceMeters.round()} m), then board a ${vehicle.label.toLowerCase()} for $destName.";
    }
    return "Board at the nearest ${vehicle.label.toLowerCase()} stand. Confirm route with driver.";
  }

  String _heuristicWhatToTake(
    String destName,
    double distanceKm,
    VehicleType vehicle,
    bool isLongDistance,
  ) {
    if (!isLongDistance) {
      switch (vehicle) {
        case VehicleType.jeepney:
          return "Tricycle (optional) to the nearest terminal, then jeepney toward $destName.";
        case VehicleType.bus:
          return "Jeepney or tricycle (optional) to a bus terminal, then bus toward $destName.";
        case VehicleType.tricycle:
          return "Tricycle to $destName.";
        case VehicleType.car:
        case VehicleType.motorcycle:
        case VehicleType.walking:
          return "Head to $destName.";
      }
    }
    switch (vehicle) {
      case VehicleType.jeepney:
        return "Long trip (~${distanceKm.toStringAsFixed(0)} km). Take jeepney to a major terminal, then transfer to an intercity ride toward $destName.";
      case VehicleType.bus:
        return "Long trip (~${distanceKm.toStringAsFixed(0)} km). Ride to the nearest bus terminal, then board an intercity bus toward $destName.";
      case VehicleType.tricycle:
        return "Tricycle to the nearest terminal, then transfer to jeepney/bus route toward $destName.";
      case VehicleType.car:
      case VehicleType.motorcycle:
      case VehicleType.walking:
        return "Head to $destName.";
    }
  }

  String _heuristicFareText(
    double distanceKm,
    VehicleType vehicle,
    bool hasFare,
    bool isLongDistance,
  ) {
    if (!hasFare) return "—";
    if (isLongDistance) {
      final range = CommuteFareReference.estimateFareRange(distanceKm, vehicle);
      return "~₱${range.minPhp}–₱${range.maxPhp} (direct segment; bus + jeepney may cost more). Based on LTFRB guidelines.";
    }
    final range = CommuteFareReference.estimateFareRange(distanceKm, vehicle);
    if (range.minPhp >= range.maxPhp) {
      return "~₱${range.minPhp}. Based on LTFRB guidelines; fares may vary.";
    }
    return "~₱${range.minPhp}–₱${range.maxPhp}. Based on LTFRB guidelines; fares may vary.";
  }
}
