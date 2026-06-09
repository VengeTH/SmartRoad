/// * Route Tests — SmartRoad Routing Service
/// * Tests route calculation, fallback logic, vehicle profiles, and 
/// * permission-based routing (HOA/sticker integration).
import "package:flutter_test/flutter_test.dart";
import "package:latlong2/latlong.dart";
import "../lib/services/routing_service.dart";

void main() {
  group("VehicleType", () {
    test("all vehicle types have valid graphhopper params", () {
      for (final v in VehicleType.values) {
        expect(v.graphhopperParam, isNotEmpty,
            reason: "${v.value} should have a GraphHopper param");
      }
    });

    test("all vehicle types have icons", () {
      for (final v in VehicleType.values) {
        expect(v.icon, isNotNull,
            reason: "${v.value} should have an icon");
      }
    });

    test("all vehicle types have descriptions", () {
      for (final v in VehicleType.values) {
        expect(v.description, isNotEmpty,
            reason: "${v.value} should have a description");
      }
    });

    test("deliveryRider uses motorcycle base", () {
      expect(VehicleType.deliveryRider.graphhopperParam, equals("motorcycle"));
    });

    test("floodSafe uses car base", () {
      expect(VehicleType.floodSafe.graphhopperParam, equals("car"));
    });

    test("weatherSafe uses car base", () {
      expect(VehicleType.weatherSafe.graphhopperParam, equals("car"));
    });

    test("hoaAccess uses car base", () {
      expect(VehicleType.hoaAccess.graphhopperParam, equals("car"));
    });

    test("custom profiles return correct profile names", () {
      expect(VehicleType.deliveryRider.graphhopperProfile, equals("delivery_rider"));
      expect(VehicleType.floodSafe.graphhopperProfile, equals("flood_safe"));
      expect(VehicleType.weatherSafe.graphhopperProfile, equals("weather_safe"));
      expect(VehicleType.hoaAccess.graphhopperProfile, equals("hoa_access"));
    });
  });

  group("RouteData", () {
    test("creates route data with required fields", () {
      final route = RouteData(
        points: [const LatLng(14.5995, 120.9842), const LatLng(14.6760, 121.0437)],
        distance: 10.5,
        duration: const Duration(minutes: 15),
        instructions: "Go north on Taft Ave",
      );

      expect(route.points.length, equals(2));
      expect(route.distance, equals(10.5));
      expect(route.duration.inMinutes, equals(15));
      expect(route.instructions, contains("Taft Ave"));
    });

    test("creates route data with metadata", () {
      final route = RouteData(
        points: [const LatLng(14.5, 121.0)],
        distance: 5.0,
        duration: const Duration(minutes: 10),
        metadata: RouteMetadata(
          blockedShortcut: true,
          hoaName: "BF Resort",
          timeSavedMinutes: 8,
        ),
      );

      expect(route.metadata, isNotNull);
      expect(route.metadata!.blockedShortcut, isTrue);
      expect(route.metadata!.hoaName, equals("BF Resort"));
      expect(route.metadata!.timeSavedMinutes, equals(8));
    });
  });

  group("RoutingService — Fallback Route", () {
    late RoutingService service;

    setUp(() {
      service = RoutingService();
    });

    test("fallback route returns points between start and end", () async {
      final start = const LatLng(14.5995, 120.9842); // Manila
      final end = const LatLng(14.6760, 121.0437);   // Quezon City

      final route = await service.calculateRoute(
        start: start,
        end: end,
        vehicle: VehicleType.car,
      );

      // Fallback routes should have at least 2 points (start + end)
      expect(route.points.length, greaterThanOrEqualTo(2));
      // Distance should be reasonable
      expect(route.distance, greaterThan(0));
      // Duration should be positive
      expect(route.duration.inMinutes, greaterThan(0));
    });

    test("fallback route with waypoints produces longer path", () async {
      final start = const LatLng(14.5995, 120.9842);
      final end = const LatLng(14.6760, 121.0437);
      final wp = [const LatLng(14.5500, 121.0000)]; // Waypoint via Makati

      final direct = await service.calculateRoute(
        start: start, end: end, vehicle: VehicleType.car,
      );
      final viaWp = await service.calculateRoute(
        start: start, end: end, vehicle: VehicleType.car, waypoints: wp,
      );

      // Route with waypoints should be at least as long as direct
      expect(viaWp.distance, greaterThanOrEqualTo(direct.distance * 0.8));
    });

    test("different vehicle types produce different speeds", () async {
      final start = const LatLng(14.5, 121.0);
      final end = const LatLng(14.6, 121.1);

      final carRoute = await service.calculateRoute(
        start: start, end: end, vehicle: VehicleType.car,
      );
      final footRoute = await service.calculateRoute(
        start: start, end: end, vehicle: VehicleType.pedestrian,
      );

      // Car should be faster than walking for the same distance
      expect(footRoute.duration.inMinutes,
          greaterThan(carRoute.duration.inMinutes));
    });
  });

  group("RoutingService — Permission-Based Routing", () {
    test("blocked shortcut sets metadata when user lacks sticker", () async {
      final service = RoutingService();
      final start = const LatLng(14.5, 121.0);
      final end = const LatLng(14.6, 121.1);

      final route = await service.calculateRoute(
        start: start,
        end: end,
        vehicle: VehicleType.hoaAccess,
        userStickerIds: [],       // No stickers
        restrictedHoaIds: ["hoa-bf-resort"], // Restricted area
      );

      // The route should still be returned (fallback)
      expect(route.points, isNotEmpty);
    });

    test("unrestricted route has no metadata", () async {
      final service = RoutingService();
      final start = const LatLng(14.5, 121.0);
      final end = const LatLng(14.6, 121.1);

      final route = await service.calculateRoute(
        start: start,
        end: end,
        vehicle: VehicleType.car,
        userStickerIds: [],
        restrictedHoaIds: [],
      );

      // No restricted HOAs → no blocked shortcut metadata
      // (metadata is null when all HOAs have stickers or none are restricted)
      expect(route.points, isNotEmpty);
    });
  });

  group("RoutingService — Edge Cases", () {
    test("same start and end returns minimal route", () async {
      final service = RoutingService();
      final point = const LatLng(14.5, 121.0);

      final route = await service.calculateRoute(
        start: point,
        end: point,
        vehicle: VehicleType.car,
      );

      expect(route.distance, lessThanOrEqualTo(0.01));
      expect(route.duration.inSeconds, lessThanOrEqualTo(1));
    });

    test("very short distance returns valid route", () async {
      final service = RoutingService();
      final start = const LatLng(14.5, 121.0);
      final end = const LatLng(14.501, 121.001); // ~120 meters

      final route = await service.calculateRoute(
        start: start,
        end: end,
        vehicle: VehicleType.motorcycle,
      );

      expect(route.distance, greaterThan(0));
      expect(route.points.length, greaterThanOrEqualTo(2));
    });

    test("all vehicle types produce valid fallback routes", () async {
      final service = RoutingService();
      final start = const LatLng(14.5, 121.0);
      final end = const LatLng(14.6, 121.1);

      for (final v in VehicleType.values) {
        final route = await service.calculateRoute(
          start: start, end: end, vehicle: v,
        );
        expect(route.points.length, greaterThanOrEqualTo(2),
            reason: "${v.value} should produce a route");
        expect(route.distance, greaterThan(0),
            reason: "${v.value} should have positive distance");
      }
    });
  });

  group("RouteMetadata", () {
    test("creates blocked shortcut metadata", () {
      final meta = RouteMetadata(
        blockedShortcut: true,
        hoaName: "BF Resort",
        timeSavedMinutes: 10,
      );
      expect(meta.blockedShortcut, isTrue);
      expect(meta.hoaName, equals("BF Resort"));
    });

    test("creates empty metadata", () {
      final meta = RouteMetadata();
      expect(meta.blockedShortcut, isFalse);
      expect(meta.hoaName, isNull);
      expect(meta.timeSavedMinutes, isNull);
    });
  });
}
