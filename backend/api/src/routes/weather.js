/**
 * SmartRoad Backend — Weather Routes
 * GET /api/weather/current    — Current weather at lat/lon
 * GET /api/weather/alerts     — Weather alerts/advisories
 */
const express = require("express");
const weatherService = require("../services/weather-service");

const router = express.Router();

router.get("/current", async (req, res, next) => {
  try {
    const { lat, lon } = req.query;
    if (!lat || !lon) {
      return res.status(400).json({ success: false, error: { code: "VALIDATION_ERROR", message: "lat and lon required" } });
    }
    const data = await weatherService.getCurrentWeather(parseFloat(lat), parseFloat(lon));
    res.json({ success: true, data });
  } catch (err) { next(err); }
});

router.get("/alerts", async (req, res, next) => {
  try {
    const { lat, lon } = req.query;
    if (!lat || !lon) {
      return res.status(400).json({ success: false, error: { code: "VALIDATION_ERROR", message: "lat and lon required" } });
    }
    const data = await weatherService.getWeatherAlerts(parseFloat(lat), parseFloat(lon));
    res.json({ success: true, data });
  } catch (err) { next(err); }
});

module.exports = router;
