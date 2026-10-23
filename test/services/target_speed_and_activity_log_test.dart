import "package:flutter_test/flutter_test.dart";
import "package:smartroad/models/required_speed_result.dart";
import "package:smartroad/models/route_activity_log.dart";
import "package:smartroad/services/route_activity_log_service.dart";
import "package:smartroad/services/target_speed_service.dart";

void main() {
  group("TargetSpeedService", () {
    final service = TargetSpeedService();

    test("computes required speed correctly on achievable schedule", () {
      final now = DateTime(2026, 10, 23, 10, 0, 0);
      // * 15 km in 30 minutes (0.5 hours) = ~30-40 km/h with delays
      final target = now.add(const Duration(minutes: 30));

      final result = service.computeRequiredSpeed(
        distanceKm: 15.0,
        targetArrivalTime: target,
        now: now,
        mode: "car",
      );

      expect(result.status, isNot(RequiredSpeedStatus.unachievable));
      expect(result.requiredSpeedKph, greaterThan(25.0));
      expect(result.legalSpeedLimitKph, equals(60));
    });

    test("flags speed exceeding legal limit with legal warning and mark", () {
      final now = DateTime(2026, 10, 23, 10, 0, 0);
      // * 30 km in 15 minutes = > 120 km/h, well over 60 km/h urban limit!
      final target = now.add(const Duration(minutes: 15));

      final result = service.computeRequiredSpeed(
        distanceKm: 30.0,
        targetArrivalTime: target,
        now: now,
        mode: "car",
      );

      expect(result.status, equals(RequiredSpeedStatus.exceedsLimit));
      expect(result.isExceedingLegalLimit, isTrue);
      expect(result.requiredSpeedKph, greaterThan(60.0));
      expect(result.statusBadge, equals("Exceeds Limit"));
      expect(result.warningMessage, contains("exceeds the legal speed limit"));
      expect(result.legalDisclaimer, contains("RA 4136"));
    });

    test("handles past target arrival time as past / unachievable", () {
      final now = DateTime(2026, 10, 23, 10, 0, 0);
      final pastTarget = now.subtract(const Duration(minutes: 5));

      final result = service.computeRequiredSpeed(
        distanceKm: 10.0,
        targetArrivalTime: pastTarget,
        now: now,
        mode: "car",
      );

      expect(result.status, equals(RequiredSpeedStatus.unachievable));
      expect(result.isUnachievable, isTrue);
      expect(result.statusBadge, equals("Past Target"));
    });

    test("accounts for pedestrian crossings and traffic delay buffers", () {
      final now = DateTime(2026, 10, 23, 10, 0, 0);
      final target = now.add(const Duration(minutes: 20));

      final resultWithDelays = service.computeRequiredSpeed(
        distanceKm: 10.0,
        targetArrivalTime: target,
        now: now,
        mode: "car",
        pedestrianCrossingsCount: 10,
        trafficDelayMinutes: 5.0,
      );

      final resultWithoutDelays = service.computeRequiredSpeed(
        distanceKm: 10.0,
        targetArrivalTime: target,
        now: now,
        mode: "car",
        pedestrianCrossingsCount: 0,
        trafficDelayMinutes: 0.0,
      );

      // * With delays, available moving time is smaller, so required moving speed must be higher
      expect(
        resultWithDelays.requiredSpeedKph,
        greaterThan(resultWithoutDelays.requiredSpeedKph),
      );
    });
  });

  group("RouteActivityLogService", () {
    final logService = RouteActivityLogService();

    setUp(() async {
      await logService.clearLogs();
    });

    test("creates search time log distinctly marked as searched only", () async {
      final log = await logService.logRouteSearch(
        originLabel: "Makati City Hall",
        destinationLabel: "BGC High Street",
        originLat: 14.564,
        originLon: 121.031,
        destinationLat: 14.551,
        destinationLon: 121.050,
        distanceKm: 4.2,
        estimatedDurationMinutes: 18,
        mode: "car",
        targetArrivalTime: DateTime.now().add(const Duration(minutes: 25)),
        requiredSpeedKph: 22.0,
        legalSpeedLimitKph: 60,
      );

      expect(log.type, equals(RouteActivityType.searched));
      expect(log.isSearchedOnly, isTrue);
      expect(log.isRideInitiated, isFalse);
      expect(log.initiatedAt, isNull);
      expect(log.searchedAt, isNotNull);

      final allLogs = await logService.getLogs();
      expect(allLogs.length, equals(1));
      expect(allLogs.first.destinationLabel, equals("BGC High Street"));
      expect(allLogs.first.type, equals(RouteActivityType.searched));
    });

    test("records initiated time log when starting a trip", () async {
      final searchLog = await logService.logRouteSearch(
        originLabel: "Ortigas Center",
        destinationLabel: "Quezon Memorial Circle",
        originLat: 14.586,
        originLon: 121.061,
        destinationLat: 14.651,
        destinationLon: 121.049,
        distanceKm: 8.5,
        estimatedDurationMinutes: 30,
        mode: "car",
      );

      // * Simulate user subsequently pressing start navigation
      final initiatedLog = await logService.logTripInitiated(
        searchLogId: searchLog.id,
        originLabel: searchLog.originLabel,
        destinationLabel: searchLog.destinationLabel,
        originLat: searchLog.originLat,
        originLon: searchLog.originLon,
        destinationLat: searchLog.destinationLat,
        destinationLon: searchLog.destinationLon,
        distanceKm: searchLog.distanceKm,
        estimatedDurationMinutes: searchLog.estimatedDurationMinutes,
        mode: searchLog.mode,
      );

      expect(initiatedLog.type, equals(RouteActivityType.initiated));
      expect(initiatedLog.isRideInitiated, isTrue);
      expect(initiatedLog.isSearchedOnly, isFalse);
      expect(initiatedLog.initiatedAt, isNotNull);
      expect(initiatedLog.searchedAt, equals(searchLog.searchedAt));

      final allLogs = await logService.getLogs();
      expect(allLogs.length, equals(1));
      expect(allLogs.first.isRideInitiated, isTrue);
    });
  });
}
