import "fare_estimator.dart";
import "gtfs_service.dart" show GTFSService, GtfsRoute, GtfsStop, GtfsStopTime, GtfsTrip, kNoGtfsCode;
import "../utils/fuel_utils.dart";

/// * Walking speed in m/s for transfer/walk legs.
const double kWalkingSpeedMps = 1.3;

/// * Transfer slack: min and max minutes between alighting and boarding.
const int kTransferSlackMin = 3;
const int kTransferSlackMax = 8;

/// * Confidence level for itinerary/leg.
enum TransitConfidence { high, medium, low }

/// * Error code when a feed exists but neither endpoint has a nearby stop.
const String kNoNearbyTransitCode = "NO_NEARBY_TRANSIT";

/// * Single leg of an itinerary (walk or transit).
class PlannerLeg {
  final String mode;
  final String startName;
  final String endName;
  final String departure;
  final String arrival;
  final double distanceM;
  final int timeMin;
  final String? vehicle;
  final double farePhp;
  final TransitConfidence confidence;

  const PlannerLeg({
    required this.mode,
    required this.startName,
    required this.endName,
    required this.departure,
    required this.arrival,
    required this.distanceM,
    required this.timeMin,
    this.vehicle,
    this.farePhp = 0,
    this.confidence = TransitConfidence.medium,
  });
}

/// * One itinerary (sequence of legs).
class PlannerItinerary {
  final int totalTimeMin;
  final int transfers;
  final double totalWalkM;
  final double fareEstimatePhp;
  final List<PlannerLeg> legs;

  const PlannerItinerary({
    required this.totalTimeMin,
    required this.transfers,
    required this.totalWalkM,
    required this.fareEstimatePhp,
    required this.legs,
  });

  double get score => (totalTimeMin + transfers * 10 + (totalWalkM / 100).round()).toDouble();
}

/// * Result of local transit plan. Either [itineraries] or [error]/[code].
class PlannerLocalResult {
  final List<PlannerItinerary>? itineraries;
  final String? error;
  final String? code;

  const PlannerLocalResult({this.itineraries, this.error, this.code});

  bool get isNoFeed => code == kNoGtfsCode;
}

/// * On-device GTFS transit planner: direct and one-transfer trips, walking legs, fare, confidence.
class PlannerLocal {
  PlannerLocal._();

  static final PlannerLocal _instance = PlannerLocal._();
  static PlannerLocal get instance => _instance;

  final GTFSService _gtfs = GTFSService();
  final FareEstimator _fare = FareEstimator.instance;

  /// * Plan transit from (fromLat, fromLon) to (toLat, toLon) at [datetime].
  /// * [maxTransfers] default 1; [maxNearestStops] default 5 per end.
  /// * Returns top 3 itineraries or error with code NO_GTFS when no feed.
  Future<PlannerLocalResult> planLocalTransit(
    double fromLat,
    double fromLon,
    double toLat,
    double toLon,
    DateTime datetime, {
    int maxTransfers = 1,
    int maxNearestStops = 5,
  }) async {
    if (!_gtfs.hasFeed) {
      await _gtfs.installFromAssets();
    }
    if (!_gtfs.hasFeed) {
      return const PlannerLocalResult(error: "no feed", code: kNoGtfsCode);
    }
    await _fare.ensureLoaded();

    final fromStops = _gtfs.nearestStops(fromLat, fromLon, limit: maxNearestStops, maxDistanceMeters: 2000);
    final toStops = _gtfs.nearestStops(toLat, toLon, limit: maxNearestStops, maxDistanceMeters: 2000);
    if (fromStops.isEmpty || toStops.isEmpty) {
      return const PlannerLocalResult(
        error: "No nearby transit stops in bundled data for this trip.",
        code: kNoNearbyTransitCode,
      );
    }

    final timeStr = _timeToStr(datetime);
    final itineraries = <PlannerItinerary>[];

    for (final fromStop in fromStops) {
      final walkFromM = FuelUtils.calculateDistance(fromLat, fromLon, fromStop.lat, fromStop.lon);
      final walkFromMin = (walkFromM / (kWalkingSpeedMps * 60)).round();

      for (final toStop in toStops) {
        final walkToM = FuelUtils.calculateDistance(toLat, toLon, toStop.lat, toStop.lon);
        final walkToMin = (walkToM / (kWalkingSpeedMps * 60)).round();

        final direct = _findDirectTrip(fromStop, toStop, timeStr, walkFromM, walkToM, walkFromMin, walkToMin);
        if (direct != null) itineraries.add(direct);

        if (maxTransfers >= 1) {
          final oneTransfer = _findOneTransfer(fromStop, toStop, timeStr, walkFromM, walkToM, walkFromMin, walkToMin);
          itineraries.addAll(oneTransfer);
        }
      }
    }

    itineraries.sort((a, b) => a.score.compareTo(b.score));
    final top = itineraries.take(3).toList();
    if (top.isEmpty) {
      return const PlannerLocalResult(error: "no itineraries", code: null);
    }
    return PlannerLocalResult(itineraries: top);
  }

  String _timeToStr(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute;
    final s = dt.second;
    return "${h.toString().padLeft(2, "0")}:${m.toString().padLeft(2, "0")}:${s.toString().padLeft(2, "0")}";
  }

  PlannerItinerary? _findDirectTrip(
    GtfsStop fromStop,
    GtfsStop toStop,
    String timeStr,
    double walkFromM,
    double walkToM,
    int walkFromMin,
    int walkToMin,
  ) {
    final stopTimesFrom = _gtfs.stopTimesForStop(fromStop.stopId, timeStr);
    for (final st in stopTimesFrom) {
      final tripTimes = _gtfs.getStopTimesForTrip(st.tripId);
      if (tripTimes.isEmpty) continue;
      GtfsStopTime? destSt;
      for (final t in tripTimes) {
        if (t.stopId == toStop.stopId && t.stopSequence > st.stopSequence) {
          destSt = t;
          break;
        }
      }
      if (destSt == null) continue;

      final depMins = GTFSService.timeToMinutes(st.departureTime);
      final arrMins = GTFSService.timeToMinutes(destSt.arrivalTime);
      var transitMin = arrMins - depMins;
      if (transitMin <= 0) transitMin += 24 * 60;

      final trip = _gtfs.getTripById(st.tripId);
      final route = trip != null ? _gtfs.getRouteById(trip.routeId) : null;
      final routeType = route?.routeType ?? 3;
      final typeKey = _routeTypeToKey(routeType);
      final fareResult = _fare.estimateFareByKey(typeKey, distanceMeters: walkFromM + (transitMin * 500) + walkToM, routeId: route?.routeId);
      final confidence = _confidenceForRouteType(routeType);
      final vehicleLabel = _vehicleLabel(route, trip);

      final transitLeg = PlannerLeg(
        mode: "transit",
        startName: fromStop.name,
        endName: toStop.name,
        departure: st.departureTime,
        arrival: destSt.arrivalTime,
        distanceM: transitMin * 500,
        timeMin: transitMin,
        vehicle: vehicleLabel,
        farePhp: fareResult.amountPhp,
        confidence: confidence,
      );
      final totalTime = walkFromMin + transitMin + walkToMin;
      final walkLegFirst = PlannerLeg(
        mode: "walk",
        startName: "Origin",
        endName: fromStop.name,
        departure: timeStr,
        arrival: timeStr,
        distanceM: walkFromM,
        timeMin: walkFromMin,
        farePhp: 0,
        confidence: TransitConfidence.high,
      );
      final walkLegLast = PlannerLeg(
        mode: "walk",
        startName: toStop.name,
        endName: "Destination",
        departure: destSt.arrivalTime,
        arrival: destSt.arrivalTime,
        distanceM: walkToM,
        timeMin: walkToMin,
        farePhp: 0,
        confidence: TransitConfidence.high,
      );
      return PlannerItinerary(
        totalTimeMin: totalTime,
        transfers: 0,
        totalWalkM: walkFromM + walkToM,
        fareEstimatePhp: fareResult.amountPhp,
        legs: [walkLegFirst, transitLeg, walkLegLast],
      );
    }
    return null;
  }

  List<PlannerItinerary> _findOneTransfer(
    GtfsStop fromStop,
    GtfsStop toStop,
    String timeStr,
    double walkFromM,
    double walkToM,
    int walkFromMin,
    int walkToMin,
  ) {
    final results = <PlannerItinerary>[];
    final stopTimesFrom = _gtfs.stopTimesForStop(fromStop.stopId, timeStr);
    final toStopId = toStop.stopId;

    for (final st1 in stopTimesFrom) {
      final trip1Times = _gtfs.getStopTimesForTrip(st1.tripId);
      for (final stMid in trip1Times) {
        if (stMid.stopSequence <= st1.stopSequence) continue;
        final midStop = _gtfs.getStopById(stMid.stopId);
        if (midStop == null) continue;
        final arr1Mins = GTFSService.timeToMinutes(stMid.arrivalTime);
        final transferStart = arr1Mins + kTransferSlackMin;
        final timeStr2 = _minutesToTimeStr(transferStart);
        final stopTimes2 = _gtfs.stopTimesForStop(stMid.stopId, timeStr2);
        for (final st2 in stopTimes2) {
          if (st2.tripId == st1.tripId) continue;
          final trip2Times = _gtfs.getStopTimesForTrip(st2.tripId);
          GtfsStopTime? destSt2;
          for (final t in trip2Times) {
            if (t.stopId == toStopId && t.stopSequence > st2.stopSequence) {
              destSt2 = t;
              break;
            }
          }
          if (destSt2 == null) continue;

          final dep1Mins = GTFSService.timeToMinutes(st1.departureTime);
          var leg1Min = arr1Mins - dep1Mins;
          if (leg1Min <= 0) leg1Min += 24 * 60;
          final dep2Mins = GTFSService.timeToMinutes(st2.departureTime);
          final arr2Mins = GTFSService.timeToMinutes(destSt2.arrivalTime);
          var leg2Min = arr2Mins - dep2Mins;
          if (leg2Min <= 0) leg2Min += 24 * 60;

          final trip1 = _gtfs.getTripById(st1.tripId);
          final route1 = trip1 != null ? _gtfs.getRouteById(trip1.routeId) : null;
          final trip2 = _gtfs.getTripById(st2.tripId);
          final route2 = trip2 != null ? _gtfs.getRouteById(trip2.routeId) : null;
          final vehicle1 = _vehicleLabel(route1, trip1);
          final vehicle2 = _vehicleLabel(route2, trip2);
          final typeKey1 = _routeTypeToKey(route1?.routeType ?? 3);
          final typeKey2 = _routeTypeToKey(route2?.routeType ?? 3);
          final fare1 = _fare.estimateFareByKey(typeKey1, distanceMeters: leg1Min * 500, routeId: route1?.routeId);
          final fare2 = _fare.estimateFareByKey(typeKey2, distanceMeters: leg2Min * 500, routeId: route2?.routeId);
          final totalFare = fare1.amountPhp + fare2.amountPhp;
          final conf1 = _confidenceForRouteType(route1?.routeType ?? 3);
          final conf2 = _confidenceForRouteType(route2?.routeType ?? 3);

          final totalTime = walkFromMin + leg1Min + kTransferSlackMin + leg2Min + walkToMin;
          results.add(PlannerItinerary(
            totalTimeMin: totalTime,
            transfers: 1,
            totalWalkM: walkFromM + walkToM,
            fareEstimatePhp: totalFare,
            legs: [
              PlannerLeg(mode: "walk", startName: "Origin", endName: fromStop.name, departure: timeStr, arrival: timeStr, distanceM: walkFromM, timeMin: walkFromMin, farePhp: 0, confidence: TransitConfidence.high),
              PlannerLeg(mode: "transit", startName: fromStop.name, endName: midStop.name, departure: st1.departureTime, arrival: stMid.arrivalTime, distanceM: leg1Min * 500, timeMin: leg1Min, vehicle: vehicle1, farePhp: fare1.amountPhp, confidence: conf1),
              PlannerLeg(mode: "walk", startName: midStop.name, endName: midStop.name, departure: stMid.arrivalTime, arrival: st2.departureTime, distanceM: 0, timeMin: kTransferSlackMin, farePhp: 0, confidence: TransitConfidence.high),
              PlannerLeg(mode: "transit", startName: midStop.name, endName: toStop.name, departure: st2.departureTime, arrival: destSt2.arrivalTime, distanceM: leg2Min * 500, timeMin: leg2Min, vehicle: vehicle2, farePhp: fare2.amountPhp, confidence: conf2),
              PlannerLeg(mode: "walk", startName: toStop.name, endName: "Destination", departure: destSt2.arrivalTime, arrival: destSt2.arrivalTime, distanceM: walkToM, timeMin: walkToMin, farePhp: 0, confidence: TransitConfidence.high),
            ],
          ));
        }
      }
    }
    return results;
  }

  String _minutesToTimeStr(int minutesFromMidnight) {
    final h = (minutesFromMidnight ~/ 60) % 24;
    final m = minutesFromMidnight % 60;
    return "${h.toString().padLeft(2, "0")}:${m.toString().padLeft(2, "0")}:00";
  }

  /// * Builds a readable route label from route and optional trip headsign; avoids raw trip_id in user-facing text.
  String _vehicleLabel(GtfsRoute? route, GtfsTrip? trip) {
    if (route == null) return "Transit";
    final headsign = trip?.tripHeadsign?.trim();
    if (headsign != null && headsign.isNotEmpty) {
      return "${route.shortName} ($headsign)".trim();
    }
    final combined = "${route.shortName} ${route.longName}".trim();
    return combined.isEmpty ? "Route ${route.shortName}" : combined;
  }

  String _routeTypeToKey(int routeType) {
    switch (routeType) {
      case 0:
        return "jeepney";
      case 1:
      case 2:
        return "lrt";
      case 3:
        return "bus";
      default:
        return "bus";
    }
  }

  TransitConfidence _confidenceForRouteType(int routeType) {
    if (routeType == 1 || routeType == 2) return TransitConfidence.high;
    if (routeType == 3) return TransitConfidence.medium;
    return TransitConfidence.low;
  }
}
