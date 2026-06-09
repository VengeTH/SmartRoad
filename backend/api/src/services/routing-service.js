/**
 * SmartRoad Backend — Routing Service
 *
 * Handles all route calculation by calling GraphHopper internally.
 * Supports multiple vehicle profiles and returns a normalized response.
 *
 * Architecture:
 *   Flutter App → SmartRoad API → RoutingService → GraphHopper
 *                 (this module)       ↓
 *                            Route post-processing
 *                            (flood check, HOA check, etc.)
 */
const http = require("http");
const https = require("https");
const config = require("../config");
const { logger } = require("../middleware/logger");
const { haversineKm, decodePolyline } = require("../utils/geo");
const { AppError } = require("../middleware/error-handler");

/**
 * HTTP agent with keep-alive for connection reuse.
 */
const httpAgent = new http.Agent({ keepAlive: true, maxSockets: 20 });

/**
 * Call GraphHopper API with timeout and retry logic.
 */
async function callGraphHopper(params, retryCount = 0) {
  const { graphhopper } = config;
  const url = new URL(`${graphhopper.url}/route`);

  Object.entries(params).forEach(([key, value]) => {
    if (Array.isArray(value)) {
      value.forEach((v) => url.searchParams.append(key, v));
    } else {
      url.searchParams.set(key, value);
    }
  });

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), graphhopper.timeoutMs);

  try {
    const response = await fetch(url.toString(), {
      signal: controller.signal,
      agent: httpAgent,
      headers: { "User-Agent": "SmartRoad-API/1.0" },
    });

    if (!response.ok) {
      const body = await response.text().catch(() => "");
      throw new AppError(
        `GraphHopper returned ${response.status}`,
        502,
        "UPSTREAM_ERROR",
        { upstreamStatus: response.status, upstreamBody: body.slice(0, 500) }
      );
    }

    return await response.json();
  } catch (err) {
    if (err.name === "AbortError") {
      logger.error(`GraphHopper timeout after ${graphhopper.timeoutMs}ms`, { url: url.toString() });
      if (retryCount < graphhopper.maxRetries) {
        logger.info(`Retrying GraphHopper call (${retryCount + 1}/${graphhopper.maxRetries})...`);
        return callGraphHopper(params, retryCount + 1);
      }
      throw new AppError("Routing service timed out", 504, "UPSTREAM_TIMEOUT");
    }
    if (err instanceof AppError) throw err;
    logger.error(`GraphHopper request failed: ${err.message}`, { stack: err.stack });
    if (retryCount < graphhopper.maxRetries) {
      logger.info(`Retrying GraphHopper call (${retryCount + 1}/${graphhopper.maxRetries})...`);
      return callGraphHopper(params, retryCount + 1);
    }
    throw new AppError("Routing service unavailable", 503, "UPSTREAM_UNAVAILABLE");
  } finally {
    clearTimeout(timeout);
  }
}

/**
 * Parse GraphHopper response into normalized route data.
 */
function parseGraphHopperResponse(data, requestedVehicle) {
  if (!data || !data.paths || data.paths.length === 0) {
    throw new AppError("No route found between the specified points", 404, "NO_ROUTE");
  }

  const path = data.paths[0];

  // Parse coordinates from points_encoded=false GeoJSON
  const coordinates = path.points?.coordinates;
  if (!coordinates || coordinates.length < 2) {
    throw new AppError("Route has insufficient geometry", 502, "INVALID_ROUTE_GEOMETRY");
  }

  const points = coordinates.map((coord) => ({
    lat: coord[1],
    lng: coord[0],
  }));

  const distanceMeters = path.distance || 0;
  const timeMs = path.time || 0;

  // Build turn-by-turn instructions
  const instructions = (path.instructions || [])
    .map((inst) => inst.text)
    .filter(Boolean)
    .join(" → ");

  // Snapshots for route context
  const distanceKm = distanceMeters / 1000;
  const durationSeconds = Math.round(timeMs / 1000);

  return {
    points,
    distance_km: Math.round(distanceKm * 100) / 100,
    distance_meters: Math.round(distanceMeters),
    duration_seconds: durationSeconds,
    duration_minutes: Math.round(durationSeconds / 60),
    duration_formatted: formatDuration(durationSeconds),
    instructions: instructions || null,
    vehicle: requestedVehicle,
    metadata: {
      time_ms: timeMs,
      distance_meters: distanceMeters,
      instructions_count: (path.instructions || []).length,
      points_count: points.length,
      ascend: path.ascend || null,
      descend: path.descend || null,
    },
  };
}

/**
 * Format seconds into human-readable duration.
 */
function formatDuration(totalSeconds) {
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  const parts = [];
  if (hours > 0) parts.push(`${hours}h`);
  if (minutes > 0) parts.push(`${minutes}m`);
  if (seconds > 0 || parts.length === 0) parts.push(`${seconds}s`);
  return parts.join(" ");
}

/**
 * Calculate a straight-line fallback route when GraphHopper is unavailable.
 * Uses Catmull–Rom interpolation through waypoints for smooth paths.
 */
function calculateFallback(start, end, vehicle, waypoints = []) {
  const allPoints = [start, ...waypoints, end];
  const interpolatedPoints = [];

  // Simple linear interpolation for fallback
  for (let i = 0; i < allPoints.length - 1; i++) {
    const from = allPoints[i];
    const to = allPoints[i + 1];
    const steps = Math.max(8, Math.ceil(haversineKm(from.lat, from.lng, to.lat, to.lng) * 8));
    for (let s = 0; s <= steps; s++) {
      const t = s / steps;
      interpolatedPoints.push({
        lat: from.lat + (to.lat - from.lat) * t,
        lng: from.lng + (to.lng - from.lng) * t,
      });
    }
  }

  // Calculate total distance
  let totalDistanceKm = 0;
  for (let i = 1; i < interpolatedPoints.length; i++) {
    totalDistanceKm += haversineKm(
      interpolatedPoints[i - 1].lat,
      interpolatedPoints[i - 1].lng,
      interpolatedPoints[i].lat,
      interpolatedPoints[i].lng
    );
  }

  // Estimate speed based on vehicle
  const speeds = {
    car: 45,
    motorcycle: 40,
    big_bike: 50,
    truck: 35,
    pedestrian: 5,
    delivery_rider: 40,
    flood_safe: 40,
    weather_safe: 40,
    hoa_access: 35,
  };
  const avgSpeed = speeds[vehicle] || 40;
  const durationHours = totalDistanceKm / avgSpeed;
  const durationSeconds = Math.round(durationHours * 3600);

  return {
    points: interpolatedPoints,
    distance_km: Math.round(totalDistanceKm * 100) / 100,
    distance_meters: Math.round(totalDistanceKm * 1000),
    duration_seconds: durationSeconds,
    duration_minutes: Math.round(durationSeconds / 60),
    duration_formatted: formatDuration(durationSeconds),
    instructions: "Direct route (offline fallback)",
    vehicle,
    is_fallback: true,
    metadata: {
      points_count: interpolatedPoints.length,
      is_fallback: true,
    },
  };
}

/**
 * Main route method — tries GraphHopper, falls back to straight-line.
 */
async function calculateRoute({
  start,
  end,
  vehicle,
  waypoints = [],
  avoidTolls = true,
  userStickerIds = [],
  restrictedHoaIds = [],
}) {
  const params = {
    point: [[start.lat, start.lng].join(",")],
    ...(waypoints.length > 0 && {
      point: waypoints.map((wp) => [wp.lat, wp.lng].join(",")),
    }),
    ...{ point: [[end.lat, end.lng].join(",")] },
    vehicle: vehicle === "pedestrian" ? "foot" : vehicle === "big_bike" ? "motorcycle" : vehicle,
    type: "json",
    instructions: "true",
    calc_points: "true",
    points_encoded: "false",
    ...(avoidTolls && { avoid: "toll" }),
  };

  // Flatten point array since GraphHopper expects multiple point params
  const allPoints = [
    `${start.lat},${start.lng}`,
    ...waypoints.map((wp) => `${wp.lat},${wp.lng}`),
    `${end.lat},${end.lng}`,
  ];
  params.point = allPoints;

  try {
    const ghResponse = await callGraphHopper(params);
    const route = parseGraphHopperResponse(ghResponse, vehicle);

    // Post-processing: HOA permission check
    if (restrictedHoaIds.length > 0 && restrictedHoaIds.length > userStickerIds.length) {
      route.hoa_warning = true;
      route.hoa_missing_stickers = restrictedHoaIds.filter(
        (id) => !userStickerIds.includes(id)
      );
    }

    return { success: true, data: route };
  } catch (err) {
    if (err instanceof AppError && err.statusCode >= 500) {
      logger.warn(`GraphHopper failed, using fallback: ${err.message}`);
      const fallback = calculateFallback(start, end, vehicle, waypoints);
      return { success: true, data: fallback, note: "Fallback route (GraphHopper unavailable)" };
    }
    throw err;
  }
}

module.exports = { calculateRoute, calculateFallback, callGraphHopper };
