/**
 * SmartRoad Backend API — Entry Point
 * 
 * Starts the Express server with all middleware and routes.
 * 
 * Architecture:
 *   Flutter App → Express API → RoutingService → GraphHopper
 *                   ↓
 *             PostgreSQL (future)
 */
const express = require("express");
const helmet = require("helmet");
const cors = require("cors");
const rateLimit = require("express-rate-limit");
const config = require("./config");
const { logger, httpLogger } = require("./middleware/logger");
const { notFoundHandler, errorHandler } = require("./middleware/error-handler");
const routes = require("./routes");

const app = express();

// ---------------------------------------------------------------------------
// Global Middleware
// ---------------------------------------------------------------------------

// Security headers
app.use(helmet());

// CORS — allow Flutter app on all origins in dev
app.use(cors({
  origin: config.isDev ? "*" : /\.smartroad\.app$/,
  methods: ["GET", "POST", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization"],
  maxAge: 86400,
}));

// Body parsing
app.use(express.json({ limit: "100kb" }));

// Rate limiting
app.use(
  rateLimit({
    windowMs: config.rateLimit.windowMs,
    max: config.rateLimit.maxRequests,
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, error: { code: "RATE_LIMITED", message: "Too many requests" } },
  })
);

// HTTP request logging
app.use(httpLogger);

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------
app.use("/api", routes);

// ---------------------------------------------------------------------------
// Error Handling
// ---------------------------------------------------------------------------
app.use(notFoundHandler);
app.use(errorHandler);

// ---------------------------------------------------------------------------
// Start Server
// ---------------------------------------------------------------------------
app.listen(config.server.port, () => {
  logger.info(`SmartRoad API started on port ${config.server.port} [${config.env}]`);
  logger.info(`GraphHopper URL: ${config.graphhopper.url}`);
});

module.exports = app; // For testing
