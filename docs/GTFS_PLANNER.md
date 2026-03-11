# GTFS Transit Planner

On-device GTFS transit planner with fare estimation and confidence scoring. When a GTFS feed is installed, the commute guide uses planner results; otherwise the app falls back to a heuristic guide with long-distance-aware copy.

## Initialize GTFS at startup

GTFS Hive boxes and adapters are initialized in `main.dart`:

```dart
await GTFSService().initializeHive();
```

This is defensive: if Hive is already initialized by another service, it does not throw. Adapters for `GtfsStop`, `GtfsRoute`, `GtfsTrip`, `GtfsStopTime`, and `List<GtfsStopTime>` are registered; boxes `gtfs_stops`, `gtfs_routes`, `gtfs_trips`, `gtfs_stop_times` are opened.

## Install or update feed

Use `GTFSService().downloadAndInstallGtfs(feedUrl)` with:

- **HTTP/HTTPS URL**: feed is downloaded and installed.
- **File path** (absolute string) or **file:// URL**: local zip is read and installed.

On success, indexes are rebuilt. On missing feed or parse failure, the method returns `(error: "no feed", code: "NO_GTFS")`.

## Fare table location

Default fare rules are loaded from the asset **`lib/config/fare_table.json`**. The file is valid JSON (no comments). It defines:

- **defaults**: jeepney, bus, tricycle, lrt, mrt, pnr, taxi, angkas (first_km/first_fare_php/per_km, flat_fare_php, or base_fare_php/per_km_php).
- **route_overrides**: optional route-specific overrides (e.g. rail).

`FareEstimator.instance.loadDefaults()` loads from the asset; `estimateFare(VehicleType, distanceMeters, routeId)` and `estimateFareByKey(typeKey, distanceMeters, routeId)` use it.

## Planner fallback behavior

- **PlannerService.plan()** calls the local GTFS planner first. Results are cached in memory by rounded origin/destination and 10‑minute time window (TTL 10 min).
- If the planner returns **no itineraries** and mode is not transit-only, the result includes **`fallback: "no-transit"`**. The UI can then offer driving directions or the heuristic commute guide.
- If there is **no feed** or **NO_GTFS**, the result has `error` and `code`; the commute screen shows the heuristic guide (long-distance aware).

## Using `fallback: "no-transit"` for driving or Mapbox

When `PlannerServiceResult.isNoTransitFallback` is true (`fallback == "no-transit"`), the app can:

- Show the heuristic commute guide (e.g. “No direct jeepney… bus/FX/terminal” for long distance).
- Offer a “Get directions” or “Drive” action that opens an external map (e.g. Mapbox, Google Maps) for driving.

No transit itinerary is shown in that case; the user can still see distance, ETA, and heuristic fare from the existing commute state.
