/**
 * SmartRoad Backend — Environment Configuration
 * Centralized config loaded from environment variables with defaults.
 */
require("dotenv").config();

const config = {
  env: process.env.NODE_ENV || "development",
  isDev: process.env.NODE_ENV !== "production",
  isProd: process.env.NODE_ENV === "production",

  server: {
    port: parseInt(process.env.PORT, 10) || 3000,
  },

  graphhopper: {
    url: process.env.GRAPH_HOPPER_URL || "http://graphhopper:8989",
    timeoutMs: parseInt(process.env.GRAPH_HOPPER_TIMEOUT_MS, 10) || 15000,
    maxRetries: parseInt(process.env.GRAPH_HOPPER_MAX_RETRIES, 10) || 2,
  },

  jwt: {
    secret: process.env.JWT_SECRET || "smartroad-dev-secret-change-in-production",
    expiresIn: process.env.JWT_EXPIRES_IN || "7d",
  },

  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS, 10) || 60000,
    maxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS, 10) || 100,
  },

  logging: {
    level: process.env.LOG_LEVEL || (process.env.NODE_ENV === "production" ? "info" : "debug"),
  },
};

module.exports = config;
