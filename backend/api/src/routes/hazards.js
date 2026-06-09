/**
 * SmartRoad Backend — Hazard Routes
 * GET    /api/hazards           — List hazards (with filters)
 * POST   /api/hazards           — Report a hazard
 * GET    /api/hazards/nearby    — Hazards near a point
 * GET    /api/hazards/bounds    — Hazards within bounding box
 * GET    /api/hazards/:id       — Get single hazard
 * PUT    /api/hazards/:id       — Update hazard
 * DELETE /api/hazards/:id       — Delete hazard
 */
const express = require("express");
const hazardService = require("../services/hazard-service");
const { requireAuth, optionalAuth } = require("../middleware/auth");
const realtime = require("../services/realtime");

const router = express.Router();

// List hazards
router.get("/", optionalAuth, (req, res) => {
  const { limit, offset, type, severity, userId } = req.query;
  const result = hazardService.getHazards({
    limit: parseInt(limit) || 50, offset: parseInt(offset) || 0,
    type, severity, userId,
  });
  res.json({ success: true, ...result });
});

// Hazards near a point
router.get("/nearby", (req, res) => {
  const { lat, lng, radiusKm } = req.query;
  if (!lat || !lng) {
    return res.status(400).json({ success: false, error: { code: "VALIDATION_ERROR", message: "lat and lng required" } });
  }
  const data = hazardService.getNearbyHazards({
    lat: parseFloat(lat), lng: parseFloat(lng),
    radiusKm: parseFloat(radiusKm) || 5,
  });
  res.json({ success: true, data, count: data.length });
});

// Hazards within bounding box
router.get("/bounds", (req, res) => {
  const { minLat, maxLat, minLng, maxLng } = req.query;
  if (!minLat || !maxLat || !minLng || !maxLng) {
    return res.status(400).json({ success: false, error: { code: "VALIDATION_ERROR", message: "minLat, maxLat, minLng, maxLng required" } });
  }
  const data = hazardService.getHazardsInBounds({
    minLat: parseFloat(minLat), maxLat: parseFloat(maxLat),
    minLng: parseFloat(minLng), maxLng: parseFloat(maxLng),
  });
  res.json({ success: true, data, count: data.length });
});

// Report a hazard
router.post("/", requireAuth, (req, res) => {
  const { type, description, severity, latitude, longitude, imageUrl } = req.body;
  const hazard = hazardService.createHazard({
    userId: req.user.id, type, description, severity, latitude, longitude, imageUrl,
  });
  realtime.notifyHazardCreated(hazard);
  res.status(201).json({ success: true, data: hazard });
});

// Get single hazard
router.get("/:id", (req, res) => {
  const hazard = hazardService.getHazardById(req.params.id);
  if (!hazard) return res.status(404).json({ success: false, error: { code: "NOT_FOUND", message: "Hazard not found" } });
  res.json({ success: true, data: hazard });
});

// Update hazard
router.put("/:id", requireAuth, (req, res) => {
  const { type, description, severity } = req.body;
  const hazard = hazardService.updateHazard(req.params.id, { type, description, severity }, req.user.id);
  realtime.notifyHazardUpdated(hazard);
  res.json({ success: true, data: hazard });
});

// Delete hazard
router.delete("/:id", requireAuth, (req, res) => {
  hazardService.deleteHazard(req.params.id, req.user.id);
  res.json({ success: true });
});

module.exports = router;
