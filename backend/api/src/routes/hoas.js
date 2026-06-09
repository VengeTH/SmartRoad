/**
 * SmartRoad Backend — HOA Routes
 * GET  /api/hoas          — List HOAs
 * POST /api/hoas/register — Register a new HOA
 * GET  /api/hoas/:id      — Get HOA details
 */
const express = require("express");
const { v4: uuidv4 } = require("uuid");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();
const hoas = new Map();

// Seed demo HOAs
const demos = [
  { id: "hoa-bf-resort", name: "BF Resort", description: "BF Resort Village", lat: 14.4244, lng: 120.9883, accessType: "public_shortcut" },
  { id: "hoa-bf-homes", name: "BF Homes", description: "BF Homes Parañaque", lat: 14.5000, lng: 121.0000, accessType: "residents_only" },
];
demos.forEach((h) => hoas.set(h.id, { ...h, isActive: true, createdAt: new Date().toISOString() }));

router.get("/", (req, res) => {
  res.json({ success: true, data: Array.from(hoas.values()) });
});

router.post("/register", requireAuth, (req, res) => {
  const { name, description, latitude, longitude, accessType } = req.body;
  if (!name) return res.status(400).json({ success: false, error: { code: "VALIDATION_ERROR", message: "name required" } });
  const id = `hoa-${uuidv4().slice(0, 8)}`;
  const hoa = { id, name, description, latitude, longitude, accessType: accessType || "public_shortcut", isActive: true, registeredBy: req.user.id, createdAt: new Date().toISOString() };
  hoas.set(id, hoa);
  res.status(201).json({ success: true, data: hoa });
});

router.get("/:id", (req, res) => {
  const hoa = hoas.get(req.params.id);
  if (!hoa) return res.status(404).json({ success: false, error: { code: "NOT_FOUND", message: "HOA not found" } });
  res.json({ success: true, data: hoa });
});

module.exports = router;
