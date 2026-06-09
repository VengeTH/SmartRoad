/**
 * SmartRoad Backend — Routing API Routes
 * POST /api/routing/route — Calculate a route
 */
const express = require("express");
const { validateRouteRequest } = require("../middleware/validator");
const routingService = require("../services/routing-service");
const { AppError } = require("../middleware/error-handler");
const { logger } = require("../middleware/logger");

const router = express.Router();

/**
 * POST /api/routing/route
 * 
 * Request body:
 * {
 *   start: { lat: 14.5995, lon: 120.9842 },
 *   end: { lat: 14.6760, lon: 121.0437 },
 *   vehicle: "motorcycle",         // or car, truck, pedestrian, delivery_rider, etc.
 *   waypoints?: [{ lat, lon }],
 *   avoid_tolls?: boolean,
 *   user_sticker_ids?: string[],
 *   restricted_hoa_ids?: string[]
 * }
 * 
 * Response:
 * {
 *   success: true,
 *   data: {
 *     points: [{ lat, lng }, ...],
 *     distance_km: 12.5,
 *     duration_seconds: 900,
 *     duration_minutes: 15,
 *     duration_formatted: "15m",
 *     instructions: "Turn left ...",
 *     vehicle: "motorcycle",
 *     metadata: { ... }
 *   }
 * }
 */
router.post("/route", validateRouteRequest, async (req, res, next) => {
  const startTime = Date.now();
  const { validated } = req;

  try {
    const result = await routingService.calculateRoute({
      start: validated.start,
      end: validated.end,
      vehicle: validated.vehicle,
      waypoints: validated.waypoints,
      avoidTolls: validated.avoidTolls,
      userStickerIds: validated.userStickerIds,
      restrictedHoaIds: validated.restrictedHoaIds,
    });

    const elapsedMs = Date.now() - startTime;
    logger.info(`Route calculated`, {
      vehicle: validated.vehicle,
      elapsedMs,
      isFallback: !!result.data?.is_fallback,
      distanceKm: result.data?.distance_km,
    });

    res.json(result);
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/routing/health — Health check
 */
router.get("/health", (req, res) => {
  res.json({
    status: "ok",
    service: "routing",
    timestamp: new Date().toISOString(),
  });
});

/**
 * GET /api/routing/vehicles — List supported vehicles
 */
router.get("/vehicles", (req, res) => {
  const { VALID_VEHICLES } = require("../middleware/validator");
  res.json({
    success: true,
    data: VALID_VEHICLES.map((v) => ({
      id: v,
      label: v.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase()),
    })),
  });
});

module.exports = router;
