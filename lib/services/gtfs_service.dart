import "dart:io";

import "package:archive/archive.dart";
import "package:csv/csv.dart";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:hive_flutter/hive_flutter.dart";
import "package:http/http.dart" as http;

import "../utils/fuel_utils.dart";

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// * GTFS stop (from stops.txt).
class GtfsStop {
  final String stopId;
  final String name;
  final double lat;
  final double lon;

  const GtfsStop({
    required this.stopId,
    required this.name,
    required this.lat,
    required this.lon,
  });
}

/// * GTFS route (from routes.txt).
class GtfsRoute {
  final String routeId;
  final String shortName;
  final String longName;
  final int routeType;

  const GtfsRoute({
    required this.routeId,
    required this.shortName,
    required this.longName,
    required this.routeType,
  });
}

/// * GTFS trip (from trips.txt). Optional [tripHeadsign] from trip_headsign when present.
class GtfsTrip {
  final String tripId;
  final String routeId;
  final String? tripHeadsign;

  const GtfsTrip({required this.tripId, required this.routeId, this.tripHeadsign});
}

/// * GTFS stop_time (from stop_times.txt). Times can be >24:00 (e.g. 25:30:00).
class GtfsStopTime {
  final String tripId;
  final String stopId;
  final String arrivalTime;
  final String departureTime;
  final int stopSequence;

  const GtfsStopTime({
    required this.tripId,
    required this.stopId,
    required this.arrivalTime,
    required this.departureTime,
    required this.stopSequence,
  });
}

// ---------------------------------------------------------------------------
// Hive TypeAdapters (typeIds 100–103)
// ---------------------------------------------------------------------------

class GtfsStopAdapter extends TypeAdapter<GtfsStop> {
  @override
  final int typeId = 100;

  @override
  GtfsStop read(BinaryReader reader) {
    return GtfsStop(
      stopId: reader.readString(),
      name: reader.readString(),
      lat: reader.readDouble(),
      lon: reader.readDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, GtfsStop obj) {
    writer.writeString(obj.stopId);
    writer.writeString(obj.name);
    writer.writeDouble(obj.lat);
    writer.writeDouble(obj.lon);
  }
}

class GtfsRouteAdapter extends TypeAdapter<GtfsRoute> {
  @override
  final int typeId = 101;

  @override
  GtfsRoute read(BinaryReader reader) {
    return GtfsRoute(
      routeId: reader.readString(),
      shortName: reader.readString(),
      longName: reader.readString(),
      routeType: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, GtfsRoute obj) {
    writer.writeString(obj.routeId);
    writer.writeString(obj.shortName);
    writer.writeString(obj.longName);
    writer.writeInt(obj.routeType);
  }
}

class GtfsTripAdapter extends TypeAdapter<GtfsTrip> {
  @override
  final int typeId = 102;

  @override
  GtfsTrip read(BinaryReader reader) {
    final tripId = reader.readString();
    final routeId = reader.readString();
    String? tripHeadsign;
    try {
      final s = reader.readString();
      tripHeadsign = s.isEmpty ? null : s;
    } catch (_) {
      tripHeadsign = null;
    }
    return GtfsTrip(tripId: tripId, routeId: routeId, tripHeadsign: tripHeadsign);
  }

  @override
  void write(BinaryWriter writer, GtfsTrip obj) {
    writer.writeString(obj.tripId);
    writer.writeString(obj.routeId);
    writer.writeString(obj.tripHeadsign ?? "");
  }
}

class GtfsStopTimeAdapter extends TypeAdapter<GtfsStopTime> {
  @override
  final int typeId = 103;

  @override
  GtfsStopTime read(BinaryReader reader) {
    return GtfsStopTime(
      tripId: reader.readString(),
      stopId: reader.readString(),
      arrivalTime: reader.readString(),
      departureTime: reader.readString(),
      stopSequence: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, GtfsStopTime obj) {
    writer.writeString(obj.tripId);
    writer.writeString(obj.stopId);
    writer.writeString(obj.arrivalTime);
    writer.writeString(obj.departureTime);
    writer.writeInt(obj.stopSequence);
  }
}

/// * Adapter for `List<GtfsStopTime>` so Hive can store stop_times per trip.
class GtfsStopTimeListAdapter extends TypeAdapter<List<GtfsStopTime>> {
  @override
  final int typeId = 104;

  @override
  List<GtfsStopTime> read(BinaryReader reader) {
    final length = reader.readInt();
    final adapter = GtfsStopTimeAdapter();
    final list = <GtfsStopTime>[];
    for (var i = 0; i < length; i++) {
      list.add(adapter.read(reader));
    }
    return list;
  }

  @override
  void write(BinaryWriter writer, List<GtfsStopTime> obj) {
    writer.writeInt(obj.length);
    final adapter = GtfsStopTimeAdapter();
    for (final e in obj) {
      adapter.write(writer, e);
    }
  }
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// * Error code when no feed is installed or parse fails.
const String kNoGtfsCode = "NO_GTFS";

/// * GTFS feed storage and installer. Uses Hive for persistence.
class GTFSService {
  GTFSService._();
  static final GTFSService _instance = GTFSService._();
  factory GTFSService() => _instance;

  static const String _boxStops = "gtfs_stops";
  static const String _boxRoutes = "gtfs_routes";
  static const String _boxTrips = "gtfs_trips";
  static const String _boxStopTimes = "gtfs_stop_times";
  static const Duration _downloadTimeout = Duration(seconds: 60);

  static Box<GtfsStop>? _stopsBox;
  static Box<GtfsRoute>? _routesBox;
  static Box<GtfsTrip>? _tripsBox;
  static Box<dynamic>? _stopTimesBox;

  /// * In-memory index: stopId -> list of (tripId, stopTime) for fast lookup.
  static final Map<String, List<GtfsStopTime>> _stopTimesByStopId = {};
  /// * In-memory index: tripId -> list of stop_times in sequence.
  static final Map<String, List<GtfsStopTime>> _stopTimesByTripId = {};
  static bool _indexBuilt = false;

  /// * Initialize Hive for GTFS: register adapters and open boxes. Defensive if already initialized.
  Future<void> initializeHive() async {
    try {
      await Hive.initFlutter();
    } catch (_) {
      // * Hive may already be initialized by another service.
    }
    _registerAdapters();
    _stopsBox ??= await Hive.openBox<GtfsStop>(_boxStops);
    _routesBox ??= await Hive.openBox<GtfsRoute>(_boxRoutes);
    _tripsBox ??= await Hive.openBox<GtfsTrip>(_boxTrips);
    _stopTimesBox ??= await Hive.openBox<dynamic>(_boxStopTimes);
    _buildIndexes();
  }

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(100)) {
      Hive.registerAdapter(GtfsStopAdapter());
    }
    if (!Hive.isAdapterRegistered(101)) {
      Hive.registerAdapter(GtfsRouteAdapter());
    }
    if (!Hive.isAdapterRegistered(102)) {
      Hive.registerAdapter(GtfsTripAdapter());
    }
    if (!Hive.isAdapterRegistered(103)) {
      Hive.registerAdapter(GtfsStopTimeAdapter());
    }
    if (!Hive.isAdapterRegistered(104)) {
      Hive.registerAdapter(GtfsStopTimeListAdapter());
    }
  }

  void _buildIndexes() {
    if (_indexBuilt) return;
    _stopTimesByStopId.clear();
    _stopTimesByTripId.clear();
    final box = _stopTimesBox;
    if (box == null) return;
    for (final key in box.keys) {
      final list = _coerceStopTimeList(box.get(key));
      if (list.isEmpty) continue;
      if (key is String && key.startsWith("t:")) {
        final tripId = key.substring(2);
        _stopTimesByTripId[tripId] = list;
        for (final st in list) {
          _stopTimesByStopId.putIfAbsent(st.stopId, () => []).add(st);
        }
      }
    }
    _indexBuilt = true;
  }

  List<GtfsStopTime> _coerceStopTimeList(dynamic raw) {
    if (raw is List<GtfsStopTime>) {
      return raw;
    }
    if (raw is List) {
      return raw.whereType<GtfsStopTime>().toList();
    }
    return const <GtfsStopTime>[];
  }

  /// * Whether any feed data is present.
  bool get hasFeed {
    final n = _stopsBox?.length ?? 0;
    return n > 0;
  }

  /// * Download feed from [feedUrl] (or open local file), unzip, parse CSV, store in Hive.
  /// * [feedId] optional identifier for the feed. On success, indexes are rebuilt.
  /// * On missing feed or parse failure, throws or returns error with code [kNoGtfsCode].
  Future<({String? error, String? code})> downloadAndInstallGtfs(
    String feedUrl, {
    String? feedId,
  }) async {
    List<int> bytes;
    final isFile = feedUrl.startsWith("file://") || (!feedUrl.startsWith("http://") && !feedUrl.startsWith("https://"));
    if (isFile) {
      var path = feedUrl.startsWith("file://") ? feedUrl.replaceFirst("file://", "") : feedUrl;
      if (path.startsWith("/") && path.length > 2 && path[2] == ":") {
        path = path.substring(1);
      }
      final file = File(path);
      if (!await file.exists()) {
        return (error: "Transit data unavailable", code: kNoGtfsCode);
      }
      bytes = await file.readAsBytes();
      return _installFromBytes(bytes);
    } else {
      if (kIsWeb && feedUrl.contains("github.com/")) {
        return await installFromAssets();
      }
      try {
        final response = await http.get(Uri.parse(feedUrl)).timeout(_downloadTimeout);
        if (response.statusCode != 200) {
          return await installFromAssets();
        }
        bytes = response.bodyBytes;
        if (bytes.isEmpty) {
          return await installFromAssets();
        }
      } catch (e) {
        return await installFromAssets();
      }
      final remoteInstallResult = await _installFromBytes(bytes);
      if (remoteInstallResult.error != null) {
        return await installFromAssets();
      }
      return remoteInstallResult;
    }
  }

  /// * Install GTFS from bundled asset zip. Tries asset keys as declared in pubspec.
  /// * On Flutter Web, only keys under the build output are reliable; prefer assets/gtfs/.
  Future<({String? error, String? code})> installFromAssets() async {
    const candidates = <String>[
      "assets/gtfs/manila_gtfs.zip",
      "test_resources/sample_gtfs.zip",
    ];
    for (final assetPath in candidates) {
      try {
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final result = await _installFromBytes(bytes);
        if (result.error == null) {
          // ignore: avoid_print
          print("GTFS: Installed from bundled asset");
          return result;
        }
      } catch (_) {
        // * Continue trying next bundled candidate (e.g. 404 on web for some paths).
      }
    }
    return (error: "Transit data unavailable", code: kNoGtfsCode);
  }

  Future<({String? error, String? code})> _installFromBytes(List<int> bytes) async {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      return (error: "Transit data unavailable", code: kNoGtfsCode);
    }

    final stops = <String, GtfsStop>{};
    final routes = <String, GtfsRoute>{};
    final trips = <String, GtfsTrip>{};
    final stopTimesByTrip = <String, List<GtfsStopTime>>{};

    for (final file in archive) {
      if (file.isFile) {
        final name = file.name.toLowerCase().replaceAll("\\", "/");
        final baseName = name.contains("/") ? name.substring(name.lastIndexOf("/") + 1) : name;
        final data = file.content as List<int>;
        final text = String.fromCharCodes(data);
        if (baseName == "stops.txt") {
          _parseStops(text, stops);
        } else if (baseName == "routes.txt") {
          _parseRoutes(text, routes);
        } else if (baseName == "trips.txt") {
          _parseTrips(text, trips);
        } else if (baseName == "stop_times.txt") {
          _parseStopTimes(text, stopTimesByTrip);
        }
      }
    }

    if (stops.isEmpty) {
      return (error: "Transit data unavailable", code: kNoGtfsCode);
    }

    final sBox = _stopsBox;
    final rBox = _routesBox;
    final tBox = _tripsBox;
    final stBox = _stopTimesBox;
    if (sBox == null || rBox == null || tBox == null || stBox == null) {
      return (error: "Transit data unavailable", code: kNoGtfsCode);
    }

    await sBox.clear();
    await rBox.clear();
    await tBox.clear();
    await stBox.clear();

    for (final s in stops.values) {
      await sBox.put(s.stopId, s);
    }
    for (final r in routes.values) {
      await rBox.put(r.routeId, r);
    }
    for (final t in trips.values) {
      await tBox.put(t.tripId, t);
    }
    for (final entry in stopTimesByTrip.entries) {
      await stBox.put("t:${entry.key}", entry.value);
    }

    _stopTimesByStopId.clear();
    _stopTimesByTripId.clear();
    _indexBuilt = false;
    _buildIndexes();
    // ignore: avoid_print
    print("GTFS loaded: ${stops.length} stops, ${routes.length} routes, ${trips.length} trips");
    return (error: null, code: null);
  }

  void _parseStops(String text, Map<String, GtfsStop> out) {
    try {
      final rows = const CsvToListConverter().convert(text);
      if (rows.isEmpty) return;
      final header = rows[0].map((e) => e.toString().toLowerCase()).toList();
      final idIdx = header.indexOf("stop_id");
      final nameIdx = header.indexOf("stop_name");
      final latIdx = header.indexOf("stop_lat");
      final lonIdx = header.indexOf("stop_lon");
      if (idIdx < 0 || nameIdx < 0 || latIdx < 0 || lonIdx < 0) return;
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length <= idIdx || row.length <= nameIdx || row.length <= latIdx || row.length <= lonIdx) continue;
        final id = _str(row[idIdx]);
        final name = _str(row[nameIdx]);
        final lat = _double(row[latIdx]);
        final lon = _double(row[lonIdx]);
        if (id.isEmpty || lat == null || lon == null) continue;
        out[id] = GtfsStop(stopId: id, name: name, lat: lat, lon: lon);
      }
    } catch (_) {}
  }

  void _parseRoutes(String text, Map<String, GtfsRoute> out) {
    try {
      final rows = const CsvToListConverter().convert(text);
      if (rows.isEmpty) return;
      final header = rows[0].map((e) => e.toString().toLowerCase()).toList();
      final idIdx = header.indexOf("route_id");
      final shortIdx = header.indexOf("route_short_name");
      final longIdx = header.indexOf("route_long_name");
      final typeIdx = header.indexOf("route_type");
      if (idIdx < 0) return;
      final shortIdxOk = shortIdx >= 0 ? shortIdx : idIdx;
      final longIdxOk = longIdx >= 0 ? longIdx : idIdx;
      final typeIdxOk = typeIdx >= 0 ? typeIdx : 0;
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length <= idIdx) continue;
        final id = _str(row[idIdx]);
        if (id.isEmpty) continue;
        final shortName = shortIdx < 0 ? id : _str(row[shortIdxOk]);
        final longName = longIdx < 0 ? shortName : _str(row[longIdxOk]);
        final type = typeIdx < 0 ? 0 : (_int(row[typeIdxOk]) ?? 0);
        out[id] = GtfsRoute(routeId: id, shortName: shortName, longName: longName, routeType: type);
      }
    } catch (_) {}
  }

  void _parseTrips(String text, Map<String, GtfsTrip> out) {
    try {
      final rows = const CsvToListConverter().convert(text);
      if (rows.isEmpty) return;
      final header = rows[0].map((e) => e.toString().toLowerCase()).toList();
      final tripIdx = header.indexOf("trip_id");
      final routeIdx = header.indexOf("route_id");
      final headsignIdx = header.indexOf("trip_headsign");
      if (tripIdx < 0 || routeIdx < 0) return;
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length <= tripIdx || row.length <= routeIdx) continue;
        final tripId = _str(row[tripIdx]);
        final routeId = _str(row[routeIdx]);
        if (tripId.isEmpty) continue;
        final headsign = headsignIdx >= 0 && row.length > headsignIdx
            ? _str(row[headsignIdx]).trim()
            : null;
        out[tripId] = GtfsTrip(
          tripId: tripId,
          routeId: routeId,
          tripHeadsign: (headsign != null && headsign.isNotEmpty) ? headsign : null,
        );
      }
    } catch (_) {}
  }

  void _parseStopTimes(String text, Map<String, List<GtfsStopTime>> out) {
    try {
      final rows = const CsvToListConverter().convert(text);
      if (rows.isEmpty) return;
      final header = rows[0].map((e) => e.toString().toLowerCase()).toList();
      final tripIdx = header.indexOf("trip_id");
      final stopIdx = header.indexOf("stop_id");
      final arrIdx = header.indexOf("arrival_time");
      final depIdx = header.indexOf("departure_time");
      final seqIdx = header.indexOf("stop_sequence");
      if (tripIdx < 0 || stopIdx < 0) return;
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length <= tripIdx || row.length <= stopIdx) continue;
        final tripId = _str(row[tripIdx]);
        final stopId = _str(row[stopIdx]);
        final arr = arrIdx >= 0 && row.length > arrIdx ? _str(row[arrIdx]) : "";
        final dep = depIdx >= 0 && row.length > depIdx ? _str(row[depIdx]) : arr;
        final seq = seqIdx >= 0 && row.length > seqIdx ? (_int(row[seqIdx]) ?? i) : i;
        if (tripId.isEmpty || stopId.isEmpty) continue;
        out.putIfAbsent(tripId, () => []).add(GtfsStopTime(
          tripId: tripId,
          stopId: stopId,
          arrivalTime: arr,
          departureTime: dep,
          stopSequence: seq,
        ));
      }
      for (final list in out.values) {
        list.sort((a, b) => a.stopSequence.compareTo(b.stopSequence));
      }
    } catch (_) {}
  }

  String _str(dynamic v) {
    if (v == null) return "";
    return v.toString().trim();
  }

  double? _double(dynamic v) {
    if (v == null) return null;
    return double.tryParse(v.toString().trim());
  }

  int? _int(dynamic v) {
    if (v == null) return null;
    return int.tryParse(v.toString().trim());
  }

  /// * Nearest stops to (lat, lon) up to [limit], within [maxDistanceMeters].
  List<GtfsStop> nearestStops(
    double lat,
    double lon, {
    int limit = 10,
    double maxDistanceMeters = 2000,
  }) {
    final box = _stopsBox;
    if (box == null || box.isEmpty) return [];
    final list = <({GtfsStop stop, double meters})>[];
    for (final stop in box.values) {
      final m = FuelUtils.calculateDistance(lat, lon, stop.lat, stop.lon);
      if (m <= maxDistanceMeters) {
        list.add((stop: stop, meters: m));
      }
    }
    list.sort((a, b) => a.meters.compareTo(b.meters));
    return list.take(limit).map((e) => e.stop).toList();
  }

  /// * Stop_times for [stopId] with departure >= [after] (HH:MM:SS or HH:MM). Handles times >24:00.
  List<GtfsStopTime> stopTimesForStop(String stopId, String after) {
    final list = _stopTimesByStopId[stopId];
    if (list == null) return [];
    final afterMins = _timeToMinutes(after);
    return list.where((st) => _timeToMinutes(st.departureTime) >= afterMins).toList();
  }

  /// * Trips that serve [stopId] with departure from that stop >= [after]. Handles >24:00.
  List<GtfsStopTime> tripsForStopAndAfter(String stopId, String after) {
    return stopTimesForStop(stopId, after);
  }

  /// * Get stop by id.
  GtfsStop? getStopById(String stopId) {
    return _stopsBox?.get(stopId);
  }

  /// * Get route by id.
  GtfsRoute? getRouteById(String routeId) {
    return _routesBox?.get(routeId);
  }

  /// * Get trip by id.
  GtfsTrip? getTripById(String tripId) {
    return _tripsBox?.get(tripId);
  }

  /// * Stop times for a trip in sequence.
  List<GtfsStopTime> getStopTimesForTrip(String tripId) {
    return _stopTimesByTripId[tripId] ?? [];
  }

  /// * Convert GTFS time (HH:MM:SS or H:MM:SS, may be 25:00:00) to minutes from midnight.
  static int timeToMinutes(String timeStr) {
    return _timeToMinutes(timeStr);
  }

  static int _timeToMinutes(String timeStr) {
    final parts = timeStr.trim().split(":");
    if (parts.isEmpty) return 0;
    final h = int.tryParse(parts[0].trim()) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? 0) : 0;
    final s = parts.length > 2 ? (int.tryParse(parts[2].trim()) ?? 0) : 0;
    return h * 60 + m + s ~/ 60;
  }
}
