/**
 * SmartRoad Backend — Request Validation Middleware
 * Validates routing request parameters.
 */
const { AppError } = require("./error-handler");

const VALID_VEHICLES = [
  "car",
  "motorcycle",
  "big_bike",
  "truck",
  "pedestrian",
  "delivery_rider",
  "flood_safe",
  "weather_safe",
  "hoa_access",
];

const VALID_PROFILES = {
  car: "car",
  motorcycle: "motorcycle",
  big_bike: "motorcycle",
  truck: "truck",
  pedestrian: "foot",
  delivery_rider: "motorcycle",
  flood_safe: "car",
  weather_safe: "car",
  hoa_access: "car",
};

/**
 * Validates a coordinate is within valid range.
 */
function isValidCoord(lat, lon) {
  return (
    typeof lat === "number" &&
    typeof lon === "number" &&
    lat >= -90 && lat <= 90 &&
    lon >= -180 && lon <= 180
  );
}

/**
 * Validates /api/routing/route request body.
 */
function validateRouteRequest(req, res, next) {
  const { start, end, vehicle, waypoints, avoid_tolls, user_sticker_ids, restricted_hoa_ids } = req.body;

  const errors = [];

  // Required: start
  if (!start || typeof start.lat !== "number" || typeof start.lon !== "number") {
    errors.push("start.lat and start.lon (numbers) are required");
  } else if (!isValidCoord(start.lat, start.lon)) {
    errors.push("start coordinates out of range");
  }

  // Required: end
  if (!end || typeof end.lat !== "number" || typeof end.lon !== "number") {
    errors.push("end.lat and end.lon (numbers) are required");
  } else if (!isValidCoord(end.lat, end.lon)) {
    errors.push("end coordinates out of range");
  }

  // Required: vehicle
  if (!vehicle) {
    errors.push("vehicle is required");
  } else if (!VALID_VEHICLES.includes(vehicle)) {
    errors.push(`invalid vehicle. Valid: ${VALID_VEHICLES.join(", ")}`);
  }

  // Optional: waypoints
  if (waypoints) {
    if (!Array.isArray(waypoints)) {
      errors.push("waypoints must be an array");
    } else {
      waypoints.forEach((wp, i) => {
        if (!isValidCoord(wp.lat, wp.lon)) {
          errors.push(`waypoints[${i}] has invalid coordinates`);
        }
      });
    }
  }

  if (errors.length > 0) {
    return next(new AppError("Validation failed", 400, "VALIDATION_ERROR", errors));
  }

  // Normalize vehicle to GraphHopper vehicle
  req.validated = {
    start,
    end,
    vehicle,
    graphhopperVehicle: VALID_PROFILES[vehicle] || "car",
    waypoints: waypoints || [],
    avoidTolls: avoid_tolls !== false,
    userStickerIds: user_sticker_ids || [],
    restrictedHoaIds: restricted_hoa_ids || [],
  };

  next();
}

module.exports = { validateRouteRequest, VALID_VEHICLES };
