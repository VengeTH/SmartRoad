import "../config/commute_fare_reference.dart";
import "../models/commute_guide_data.dart";
import "../models/commute_state.dart";
import "commute_ai_assistant_service.dart";
import "planner_local.dart";
import "planner_service.dart";
import "transit_stop_service.dart";

/// * Long-distance threshold in km; beyond this, heuristic avoids claiming direct jeepney.
const double kLongDistanceKm = 25.0;

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
    final start = state.startPosition ?? state.currentPosition;
    final dest = state.destination;
    final isPt = vehicle == VehicleType.jeepney ||
        vehicle == VehicleType.bus ||
        vehicle == VehicleType.tricycle;
    final isLongDistance = distanceKm >= kLongDistanceKm && isPt;

    // * Reuse stored transit itinerary from state so we do not replan on every refresh.
    final stored = state.transitItinerary;
    if (stored is PlannerItinerary) {
      return _fromGtfsItinerary(stored);
    }

    if (start != null && dest != null) {
      final planResult = await PlannerService.instance.plan(
        fromLat: start.latitude,
        fromLon: start.longitude,
        toLat: dest.latitude,
        toLon: dest.longitude,
        datetime: DateTime.now(),
      );
      if (planResult.hasItineraries && planResult.itineraries != null && planResult.itineraries!.isNotEmpty) {
        return _fromGtfsItinerary(planResult.itineraries!.first);
      }
    }

    TransitStopInfo? nearestStop;
    if (isPt && start != null) {
      nearestStop = await TransitStopService.instance.getNearestTransitStop(start);
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

    final aug = await CommuteAiAssistantService.instance.getGuideAugmentation(
      destinationName: state.destinationName ?? "destination",
      vehicleType: vehicle,
      distanceKm: distanceKm,
      currentWhereToBoard: guide.whereToBoard,
      currentWhatToTake: guide.whatToTake,
      currentNotes: guide.notes,
    );
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

  CommuteGuideData _fromGtfsItinerary(PlannerItinerary itinerary) {
    final transitLegs = itinerary.legs.where((l) => l.mode == "transit").toList();
    final firstTransitLeg = transitLegs.isEmpty ? null : transitLegs.first;
    final walkLegs = itinerary.legs.where((l) => l.mode == "walk").toList();
    final firstWalkLeg = walkLegs.isEmpty ? null : walkLegs.first;
    final boardWalkM = firstWalkLeg?.distanceM ?? 0.0;
    final totalWalkM = itinerary.totalWalkM;
    final totalTime = itinerary.totalTimeMin;

    final whereToBoard = firstTransitLeg != null
        ? "${firstTransitLeg.startName} (~${boardWalkM.round()} m walk)"
        : "Board at first transit stop.";

    final whatToTake = _formatTransitLegs(transitLegs);

    final fare = itinerary.fareEstimatePhp;
    final minFare = (fare * 0.9).floor().clamp(1.0, fare);
    final maxFare = (fare * 1.15).ceil().clamp(fare, 9999.0);
    final estimatedFareText = minFare >= maxFare
        ? "~₱${fare.toStringAsFixed(0)}. Fares may vary."
        : "~₱${minFare.toStringAsFixed(0)}–₱${maxFare.toStringAsFixed(0)}. Fares may vary.";

    final distanceAndTime = "~$totalTime min total, ~${(totalWalkM / 1000).toStringAsFixed(1)} km walk.";

    final notes = _gtfsNotes(itinerary);

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

  /// * Avoid raw trip_id in user-facing text; use a short readable label.
  String _readableRouteLabel(String vehicle) {
    if (vehicle.isEmpty) return "Transit";
    if (vehicle.length > 30 && !vehicle.contains(" ")) return "Route";
    return vehicle;
  }

  String _gtfsNotes(PlannerItinerary itinerary) {
    final parts = <String>["Fares may vary. Have exact change when possible."];
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

    const notes = "Fares may vary. Have exact change when possible.";

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
        return "Nearest transit stop: ${nearestStop.name} (~${nearestStop.distanceMeters.round()} m). "
            "For this distance there may be no direct route—ask at the terminal for options to $destName.";
      }
      return "No route-specific data for this distance. Ask at the nearest terminal for options to $destName.";
    }
    if (nearestStop != null) {
      return "Nearest stop: ${nearestStop.name} (~${nearestStop.distanceMeters.round()} m). Confirm route with driver.";
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
          return "${vehicle.label} toward $destName. Ask driver if unsure.";
        case VehicleType.bus:
          return "${vehicle.label} toward $destName.";
        case VehicleType.tricycle:
          return "${vehicle.label} to $destName.";
        case VehicleType.car:
        case VehicleType.motorcycle:
        case VehicleType.walking:
          return "Head to $destName.";
      }
    }
    switch (vehicle) {
      case VehicleType.jeepney:
        return "Long trip (~${distanceKm.toStringAsFixed(0)} km). No route-specific data. Ask at the nearest terminal for options to $destName.";
      case VehicleType.bus:
        return "Long trip (~${distanceKm.toStringAsFixed(0)} km). Ask at the terminal for bus options to $destName.";
      case VehicleType.tricycle:
        return "Tricycle is for short trips. For ~${distanceKm.toStringAsFixed(0)} km ask at the terminal for bus or other options.";
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
