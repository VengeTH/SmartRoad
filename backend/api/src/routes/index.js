/**
 * SmartRoad Backend — Route Aggregator
 * Mounts all API route modules under /api.
 */
const express = require("express");
const routingRoutes = require("./routing");

const router = express.Router();

// Health check at root
router.get("/health", (req, res) => {
  res.json({ status: "ok", service: "smartroad-api", timestamp: new Date().toISOString() });
});

// Mount route modules
router.use("/routing", routingRoutes);

// Future modules will be mounted here:
// router.use("/auth", authRoutes);
// router.use("/hazards", hazardRoutes);
// router.use("/weather", weatherRoutes);
// router.use("/marketplace", marketplaceRoutes);

module.exports = router;
