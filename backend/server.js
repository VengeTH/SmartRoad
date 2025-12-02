/**
 * SmartRoad MVP Routing Backend
 * Simple Express server that proxies routing requests to GraphHopper
 */

const express = require("express");
const cors = require("cors");
const axios = require("axios");
require("dotenv").config();

const app = express();
const PORT = process.env.PORT || 3000;
const GRAPHHOPPER_URL = process.env.GRAPHHOPPER_URL || "http://localhost:8989";

// * Middleware
app.use(cors());
app.use(express.json());

/**
 * POST /route
 * Calculate route using GraphHopper
 * 
 * Request body:
 * {
 *   origin: { lat: number, lng: number },
 *   destination: { lat: number, lng: number },
 *   mode: "car" | "motorcycle",
 *   avoid_tolls: boolean
 * }
 */
app.post("/route", async (req, res) => {
  try {
    const { origin, destination, mode, avoid_tolls } = req.body;

    // * Validate input
    if (!origin || !destination || !mode) {
      return res.status(400).json({
        error: "Missing required fields: origin, destination, mode"
      });
    }

    if (!origin.lat || !origin.lng || !destination.lat || !destination.lng) {
      return res.status(400).json({
        error: "Invalid coordinates format"
      });
    }

    if (mode !== "car" && mode !== "motorcycle") {
      return res.status(400).json({
        error: "Mode must be 'car' or 'motorcycle'"
      });
    }

    // * Build GraphHopper API request
    const avoidParams = [];
    if (avoid_tolls === true) {
      avoidParams.push("toll");
    }

    // * GraphHopper endpoint
    const ghUrl = `${GRAPHHOPPER_URL}/route`;
    const params = new URLSearchParams({
      point: `${origin.lat},${origin.lng}`,
      point: `${destination.lat},${destination.lng}`,
      vehicle: mode,
      type: "json",
      instructions: "false",
      points_encoded: "false",
      alternatives: "1", // * Get 1 alternative route
    });

    if (avoidParams.length > 0) {
      params.append("avoid", avoidParams.join(","));
    }

    // * Call GraphHopper
    const response = await axios.get(`${ghUrl}?${params.toString()}`);

    if (!response.data || !response.data.paths || response.data.paths.length === 0) {
      return res.status(404).json({
        error: "No route found"
      });
    }

    // * Transform GraphHopper response to SmartRoad format
    const routes = response.data.paths.map((path) => {
      const coordinates = path.points?.coordinates || [];
      
      return {
        geometry: coordinates.map((coord) => [coord[1], coord[0]]), // * Convert [lng, lat] to [lat, lng]
        distance_meters: Math.round(path.distance || 0),
        duration_seconds: Math.round((path.time || 0) / 1000), // * GraphHopper returns time in milliseconds
        profile: mode,
      };
    });

    res.json({
      routes: routes
    });

  } catch (error) {
    console.error("Routing error:", error.message);
    
    if (error.response) {
      return res.status(error.response.status || 500).json({
        error: "GraphHopper API error",
        details: error.response.data
      });
    }

    res.status(500).json({
      error: "Internal server error",
      details: error.message
    });
  }
});

/**
 * Health check endpoint
 */
app.get("/health", (req, res) => {
  res.json({ status: "ok", service: "smartroad-routing" });
});

app.listen(PORT, () => {
  console.log(`SmartRoad Routing Backend running on port ${PORT}`);
  console.log(`GraphHopper URL: ${GRAPHHOPPER_URL}`);
});




