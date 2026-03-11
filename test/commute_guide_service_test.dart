import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:hive_flutter/hive_flutter.dart";
import "package:latlong2/latlong.dart";

import "package:smartroad/config/commute_fare_reference.dart";
import "package:smartroad/models/commute_state.dart";
import "package:smartroad/models/commute_guide_data.dart";
import "package:smartroad/services/commute_guide_service.dart";
import "package:smartroad/services/commute_ai_assistant_service.dart";

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tempDir = await Directory.systemTemp.createTemp("commute_guide_test");
    Hive.init(tempDir.path);
  });

  group("CommuteFareReference.estimateFareRange", () {
    test("returns minPhp <= maxPhp for jeepney", () {
      final r = CommuteFareReference.estimateFareRange(5.0, VehicleType.jeepney);
      expect(r.minPhp, lessThanOrEqualTo(r.maxPhp));
      expect(r.minPhp, greaterThanOrEqualTo(1));
    });

    test("returns minPhp <= maxPhp for bus", () {
      final r = CommuteFareReference.estimateFareRange(10.0, VehicleType.bus);
      expect(r.minPhp, lessThanOrEqualTo(r.maxPhp));
      expect(r.minPhp, greaterThanOrEqualTo(1));
    });

    test("returns zero range for car", () {
      final r = CommuteFareReference.estimateFareRange(10.0, VehicleType.car);
      expect(r.minPhp, 0);
      expect(r.maxPhp, 0);
    });
  });

  group("CommuteGuideService", () {
    test("buildGuide returns guide with all sections non-empty for state with destination", () async {
      final state = CommuteState(
        destination: const LatLng(14.5766, 120.9867),
        destinationName: "Robinsons Ermita",
        distanceToDestinationMeters: 5000,
        etaToDestination: const Duration(minutes: 25),
        startPosition: const LatLng(14.55, 120.98),
      );
      final guide = await CommuteGuideService.instance.buildGuide(state);
      expect(guide.whereToBoard, isNotEmpty);
      expect(guide.whatToTake, isNotEmpty);
      expect(guide.estimatedFareText, isNotEmpty);
      expect(guide.distanceAndTime, isNotEmpty);
      expect(guide.notes, isNotEmpty);
    });

    test("heuristic guide with fare vehicle includes fare range or single value", () async {
      final state = CommuteState(
        destination: const LatLng(14.58, 120.99),
        destinationName: "Test",
        distanceToDestinationMeters: 8000,
        etaToDestination: const Duration(minutes: 30),
        startPosition: const LatLng(14.56, 120.98),
        settings: const CommuteSettings(vehicleType: VehicleType.jeepney),
      );
      final guide = await CommuteGuideService.instance.buildGuide(state);
      expect(guide.estimatedFareText, contains("₱"));
      expect(guide.isFromGtfs, isFalse);
    });

    test("CommuteGuideData from GTFS has qualityHigh true", () {
      const guide = CommuteGuideData(
        whereToBoard: "Stop A",
        whatToTake: "Bus 1",
        estimatedFareText: "~₱20",
        distanceAndTime: "30 min",
        notes: "Fares may vary.",
        isFromGtfs: true,
        qualityHigh: true,
      );
      expect(guide.qualityHigh, isTrue);
      expect(guide.isFromGtfs, isTrue);
    });
  });

  group("CommuteAiAssistantService", () {
    test("getGuideAugmentation returns null or augmentation without throwing", () async {
      final aug = await CommuteAiAssistantService.instance.getGuideAugmentation(
        destinationName: "Robinsons Ermita",
        vehicleType: VehicleType.jeepney,
        distanceKm: 30,
        currentWhereToBoard: "Board at terminal.",
        currentWhatToTake: "Bus to Manila.",
        currentNotes: "Fares may vary.",
      );
      expect(aug == null || !aug.isEmpty, isTrue);
    });
  });
}
