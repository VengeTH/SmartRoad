/**
 * SmartRoad Backend — Route Aggregator
 * Mounts all API route modules under /api.
 */
const express = require("express");
const routingRoutes = require("./routing");
const authRoutes = require("./auth");
const profileRoutes = require("./profile");
const hazardRoutes = require("./hazards");
const weatherRoutes = require("./weather");
const communityRoutes = require("./community");
const entranceRoutes = require("./entrances");
const floodZoneRoutes = require("./flood-zones");
const hoaRoutes = require("./hoas");

const router = express.Router();

// Health check at root
router.get("/health", (req, res) => {
  res.json({ status: "ok", service: "smartroad-api", timestamp: new Date().toISOString() });
});

// Mount route modules
router.use("/routing", routingRoutes);
router.use("/auth", authRoutes);
router.use("/profile", profileRoutes);
router.use("/hazards", hazardRoutes);
router.use("/weather", weatherRoutes);
router.use("/community", communityRoutes);
router.use("/entrances", entranceRoutes);
router.use("/flood-zones", floodZoneRoutes);
router.use("/hoas", hoaRoutes);

module.exports = router;
