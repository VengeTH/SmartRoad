import "dart:io";

import "package:archive/archive.dart";
import "package:flutter_test/flutter_test.dart";
import "package:hive_flutter/hive_flutter.dart";

import "package:smartroad/services/gtfs_service.dart";
import "package:smartroad/services/planner_local.dart";

const String _stopsCsv = "stop_id,stop_name,stop_lat,stop_lon\ns1,Stop A,14.5,120.9\ns2,Stop B,14.51,120.91\n";
const String _routesCsv = "route_id,route_short_name,route_long_name,route_type\nr1,1,Line 1,3\n";
const String _tripsCsv = "route_id,trip_id\nr1,t1\n";
const String _stopTimesCsv = "trip_id,arrival_time,departure_time,stop_id,stop_sequence\nt1,08:00:00,08:00:00,s1,1\nt1,08:15:00,08:15:00,s2,2\n";

void main() {
  group("PlannerLocal", () {
    late String sampleZipPath;
    late Directory tempDir;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tempDir = await Directory.systemTemp.createTemp("gtfs_test");
      Hive.init(tempDir.path);
      final fromDisk = File("test_resources/sample_gtfs.zip");
      if (await fromDisk.exists()) {
        sampleZipPath = fromDisk.absolute.path;
        return;
      }
      final zipFile = File("${tempDir.path}/sample_gtfs.zip");
      final archive = Archive();
      archive.addFile(ArchiveFile("stops.txt", _stopsCsv.length, _stopsCsv.codeUnits));
      archive.addFile(ArchiveFile("routes.txt", _routesCsv.length, _routesCsv.codeUnits));
      archive.addFile(ArchiveFile("trips.txt", _tripsCsv.length, _tripsCsv.codeUnits));
      archive.addFile(ArchiveFile("stop_times.txt", _stopTimesCsv.length, _stopTimesCsv.codeUnits));
      final encoded = ZipEncoder().encode(archive);
      if (encoded != null) await zipFile.writeAsBytes(encoded);
      sampleZipPath = zipFile.absolute.path;
    });

    test("init Hive and install sample GTFS from file, then planLocalTransit returns at least one itinerary with fare", () async {
      final gtfs = GTFSService();
      await gtfs.initializeHive();

      final installResult = await gtfs.downloadAndInstallGtfs(sampleZipPath);
      expect(installResult.error, isNull);
      expect(installResult.code, isNull);
      expect(gtfs.hasFeed, isTrue);

      final planner = PlannerLocal.instance;
      final fromLat = 14.5;
      final fromLon = 120.9;
      final toLat = 14.51;
      final toLon = 120.91;
      final result = await planner.planLocalTransit(
        fromLat,
        fromLon,
        toLat,
        toLon,
        DateTime(2026, 3, 11, 7, 55),
      );

      expect(result.isNoFeed, isFalse);
      expect(result.itineraries, isNotNull);
      expect(result.itineraries!.length, greaterThanOrEqualTo(1));

      final it = result.itineraries!.first;
      expect(it.legs, isNotEmpty);
      expect(it.totalTimeMin, greaterThanOrEqualTo(0));
      expect(it.fareEstimatePhp, greaterThanOrEqualTo(0));
      expect(it.transfers, greaterThanOrEqualTo(0));
      expect(it.totalWalkM, greaterThanOrEqualTo(0));
    });
  });
}
