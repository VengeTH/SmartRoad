/**
 * SmartRoad Backend — Village Entrance Routes
 * GET    /api/entrances          — List entrances (filtered by hoaId, type)
 * POST   /api/entrances          — Suggest a new entrance
 * PUT    /api/entrances/:id/verify  — Verify an entrance (admin)
 * GET    /api/entrances/nearby   — Entrances near a point
 */
const express = require("express");
const entranceService = require("../services/entrance-service");
const { requireAuth } = require("../middleware/auth");
const { haversineKm } = require("../utils/geo");

const router = express.Router();

router.get("/", (req, res) => {
  const { hoaId, type, verified } = req.query;
  const data = entranceService.getEntrances({
    hoaId, type, verified: verified !== undefined ? verified === "true" : undefined,
  });
  res.json({ success: true, data, count: data.length });
});

router.post("/", requireAuth, (req, res) => {
  const entrance = entranceService.createEntrance({ ...req.body, userId: req.user.id });
  res.status(201).json({ success: true, data: entrance });
});

router.put("/:id/verify", requireAuth, (req, res) => {
  const entrance = entranceService.verifyEntrance(req.params.id, req.user.id);
  res.json({ success: true, data: entrance });
});

router.get("/nearby", (req, res) => {
  const { lat, lng, radiusKm } = req.query;
  if (!lat || !lng) return res.status(400).json({ success: false, error: { code: "VALIDATION_ERROR", message: "lat and lng required" } });
  const all = entranceService.getEntrances({});
  const nearby = all.filter((e) => haversineKm(parseFloat(lat), parseFloat(lng), e.latitude, e.longitude) <= (parseFloat(radiusKm) || 2));
  res.json({ success: true, data: nearby, count: nearby.length });
});

module.exports = router;
