/**
 * SmartRoad Backend — Hazard Service
 * CRUD for road hazard reports (SmartRoad.hazards).
 * In-memory store with spatial proximity queries.
 */
const { v4: uuidv4 } = require("uuid");
const { AppError } = require("../middleware/error-handler");
const { haversineKm } = require("../utils/geo");

const hazards = new Map();

// Seed demo hazards
_seedDemoHazards();

function _seedDemoHazards() {
  const demos = [
    { type: "pothole", lat: 14.5995, lng: 120.9842, severity: "Medium", description: "Large pothole on Taft Ave" },
    { type: "flood", lat: 14.5500, lng: 121.0000, severity: "High", description: "Flooding in Makati" },
    { type: "accident", lat: 14.6200, lng: 121.0100, severity: "High", description: "Multi-vehicle collision" },
  ];
  demos.forEach((d) => {
    const id = uuidv4();
    hazards.set(id, { id, userId: "demo-user-id", ...d, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
  });
}

/**
 * Create a hazard report.
 */
function createHazard({ userId, type, description, severity, latitude, longitude, imageUrl }) {
  if (!type || !description || !severity || latitude == null || longitude == null) {
    throw new AppError("type, description, severity, latitude, longitude are required", 400, "VALIDATION_ERROR");
  }

  const id = uuidv4();
  const hazard = {
    id, userId, type, description, severity,
    latitude, longitude,
    imageUrl: imageUrl || null,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  hazards.set(id, hazard);
  return hazard;
}

/**
 * Get hazards with optional filters.
 */
function getHazards({ limit = 50, offset = 0, type, severity, userId } = {}) {
  let list = Array.from(hazards.values());
  if (type) list = list.filter((h) => h.type === type);
  if (severity) list = list.filter((h) => h.severity === severity);
  if (userId) list = list.filter((h) => h.userId === userId);
  list.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  return { data: list.slice(offset, offset + limit), total: list.length };
}

/**
 * Get hazards within a bounding box.
 */
function getHazardsInBounds({ minLat, maxLat, minLng, maxLng }) {
  return Array.from(hazards.values()).filter((h) =>
    h.latitude >= minLat && h.latitude <= maxLat &&
    h.longitude >= minLng && h.longitude <= maxLng
  ).sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
}

/**
 * Get hazards near a point within radius (km).
 */
function getNearbyHazards({ lat, lng, radiusKm = 5 }) {
  return Array.from(hazards.values()).filter((h) => {
    const dist = haversineKm(lat, lng, h.latitude, h.longitude);
    return dist <= radiusKm;
  }).sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
}

/**
 * Get a single hazard by ID.
 */
function getHazardById(id) {
  return hazards.get(id) || null;
}

/**
 * Update a hazard.
 */
function updateHazard(id, updates, userId) {
  const hazard = hazards.get(id);
  if (!hazard) throw new AppError("Hazard not found", 404, "NOT_FOUND");
  if (hazard.userId !== userId) throw new AppError("Not authorized", 403, "FORBIDDEN");

  Object.assign(hazard, updates, { updatedAt: new Date().toISOString() });
  hazards.set(id, hazard);
  return hazard;
}

/**
 * Delete a hazard.
 */
function deleteHazard(id, userId) {
  const hazard = hazards.get(id);
  if (!hazard) return;
  if (hazard.userId !== userId) throw new AppError("Not authorized", 403, "FORBIDDEN");
  hazards.delete(id);
}

module.exports = {
  createHazard, getHazards, getHazardsInBounds, getNearbyHazards,
  getHazardById, updateHazard, deleteHazard,
};
