/**
 * SmartRoad Backend — Flood Zone Routes
 * GET    /api/flood-zones       — List active flood zones
 * POST   /api/flood-zones       — Report a flood zone (admin)
 * GET    /api/flood-zones/nearby— Flood zones near a point
 */
const express = require("express");
const { v4: uuidv4 } = require("uuid");
const { requireAuth } = require("../middleware/auth");
const { haversineKm } = require("../utils/geo");

const router = express.Router();
const zones = new Map();

// Seed demo flood zones
const demos = [
  { name: "Pasig River Basin", severity: "high", lat: 14.5600, lng: 121.0500, radiusKm: 3 },
  { name: "Taft Ave Flooding", severity: "moderate", lat: 14.5400, lng: 120.9900, radiusKm: 1.5 },
  { name: "Marikina Flood Plain", severity: "extreme", lat: 14.6300, lng: 121.1000, radiusKm: 5 },
];
demos.forEach((z) => {
  const id = uuidv4();
  zones.set(id, { id, createdAt: new Date().toISOString(), ...z });
});

router.get("/", (req, res) => {
  const { severity } = req.query;
  let list = Array.from(zones.values()).filter((z) => z.isActive !== false);
  if (severity) list = list.filter((z) => z.severity === severity);
  res.json({ success: true, data: list, count: list.length });
});

router.post("/", requireAuth, (req, res) => {
  const { name, severity, lat, lng, radiusKm } = req.body;
  if (!name || lat == null || lng == null) {
    return res.status(400).json({ success: false, error: { code: "VALIDATION_ERROR", message: "name, lat, lng required" } });
  }
  const id = uuidv4();
  const zone = { id, name, severity: severity || "moderate", latitude: lat, longitude: lng, radiusKm: radiusKm || 1, createdAt: new Date().toISOString() };
  zones.set(id, zone);
  res.status(201).json({ success: true, data: zone });
});

router.get("/nearby", (req, res) => {
  const { lat, lng } = req.query;
  if (!lat || !lng) return res.status(400).json({ success: false, error: { code: "VALIDATION_ERROR", message: "lat and lng required" } });
  const nearby = Array.from(zones.values()).filter((z) => {
    if (z.isActive === false) return false;
    return haversineKm(parseFloat(lat), parseFloat(lng), z.latitude, z.longitude) <= (z.radiusKm || 1);
  });
  res.json({ success: true, data: nearby, count: nearby.length });
});

module.exports = router;
