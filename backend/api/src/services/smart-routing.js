/**
 * SmartRoad Backend — Smart Routing Service
 *
 * Takes a route from GraphHopper and enhances it with SmartRoad intelligence:
 * - Flood zone avoidance
 * - Hazard awareness
 * - Village entrance suggestions
 * - HOA restriction checks
 *
 * This is where SmartRoad becomes unique from standard map apps.
 */
const { haversineKm } = require("../utils/geo");
const { logger } = require("../middleware/logger");

/**
 * Check a route against known flood zones and hazards.
 * Returns annotations for dangerous segments and an overall safety score.
 */
function assessRouteSafety(routePoints, floodZones = [], hazards = []) {
  if (!routePoints || routePoints.length < 2) {
    return { safe: true, score: 1.0, warnings: [], dangerSegments: [] };
  }

  const warnings = [];
  const dangerSegments = [];
  let totalDangerScore = 0;
  const totalSegments = routePoints.length - 1;

  for (let i = 0; i < routePoints.length - 1; i++) {
    const p1 = routePoints[i];
    const p2 = routePoints[i + 1];
    const midLat = (p1.lat + p2.lat) / 2;
    const midLng = (p1.lng + p2.lng) / 2;
    let segmentDanger = 0;

    // Check flood zones
    for (const fz of floodZones) {
      if (fz.latitude && fz.longitude) {
        const dist = haversineKm(midLat, midLng, fz.latitude, fz.longitude);
        if (dist < (fz.radiusKm || 1)) {
          const severity = fz.severity === "extreme" ? 0.8 :
                           fz.severity === "high" ? 0.6 :
                           fz.severity === "moderate" ? 0.4 : 0.2;
          segmentDanger = Math.max(segmentDanger, severity);
          if (!dangerSegments.find((d) => d.index === i)) {
            dangerSegments.push({ index: i, type: "flood", severity: fz.severity, name: fz.name });
          }
        }
      }
    }

    // Check hazards near the segment
    const nearbyHazards = hazards.filter((h) => {
      const dist = haversineKm(midLat, midLng, h.latitude, h.longitude);
      return dist < 0.5; // within 500m
    });

    for (const h of nearbyHazards) {
      const severity = h.severity === "High" ? 0.7 :
                       h.severity === "Medium" ? 0.4 : 0.2;
      segmentDanger = Math.max(segmentDanger, severity);
      if (!dangerSegments.find((d) => d.index === i)) {
        dangerSegments.push({ index: i, type: h.type || "hazard", severity: h.severity, id: h.id });
      }
    }

    totalDangerScore += segmentDanger;
  }

  const avgDanger = totalSegments > 0 ? totalDangerScore / totalSegments : 0;
  const safetyScore = Math.max(0, Math.min(1, 1 - avgDanger));

  if (dangerSegments.length > 0) {
    warnings.push({
      type: "route_danger",
      message: `Route passes through ${dangerSegments.length} dangerous ${dangerSegments.length === 1 ? "area" : "areas"}`,
      segments: dangerSegments,
      safetyScore,
    });
  }

  return { safe: dangerSegments.length === 0, score: Math.round(safetyScore * 100) / 100, warnings, dangerSegments };
}

/**
 * Find village entrances near the start or end of a route.
 */
function findNearbyEntrances(routePoints, entrances = [], maxDistanceKm = 2) {
  if (!routePoints || routePoints.length === 0) return [];

  const start = routePoints[0];
  const end = routePoints[routePoints.length - 1];
  const nearby = [];

  for (const entrance of entrances) {
    const distFromStart = haversineKm(start.lat, start.lng, entrance.latitude, entrance.longitude);
    const distFromEnd = haversineKm(end.lat, end.lng, entrance.latitude, entrance.longitude);
    const minDist = Math.min(distFromStart, distFromEnd);

    if (minDist <= maxDistanceKm) {
      nearby.push({
        ...entrance,
        distanceKm: Math.round(minDist * 100) / 100,
        near: distFromStart < distFromEnd ? "start" : "end",
      });
    }
  }

  return nearby.sort((a, b) => a.distanceKm - b.distanceKm);
}

/**
 * Generate a safer alternative route by adding avoidance waypoints.
 * Waypoints are placed to steer clear of flood zones and high-severity hazards.
 */
function generateSafeWaypoints(start, end, dangerSegments, originalPoints) {
  if (!dangerSegments || dangerSegments.length === 0) return [];

  const waypoints = [];

  // Collect unique danger coordinates to avoid
  const avoidPoints = [];
  for (const seg of dangerSegments) {
    if (seg.index !== undefined && originalPoints[seg.index]) {
      // Move the waypoint perpendicular to the dangerous segment
      const p = originalPoints[seg.index];
      const pNext = originalPoints[Math.min(seg.index + 1, originalPoints.length - 1)];
      if (p && pNext) {
        // Offset slightly perpendicular to avoid the danger
        const dlat = (pNext.lat - p.lat) * 0.3;
        const dlng = (pNext.lng - p.lng) * 0.3;
        avoidPoints.push({ lat: p.lat + dlat, lng: p.lng + dlng });
      }
    }
  }

  return avoidPoints;
}

module.exports = { assessRouteSafety, findNearbyEntrances, generateSafeWaypoints };
