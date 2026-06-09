/**
 * SmartRoad Backend API — Entry Point
 *
 * Starts the Express server with all middleware, routes, and
 * WebSocket support for realtime updates.
 *
 * Architecture:
 *   Flutter App → Express API → Services → GraphHopper / PostgreSQL
 *                   ↓
 *             WebSocket (realtime)
 */
const http = require("http");
const express = require("express");
const helmet = require("helmet");
const cors = require("cors");
const rateLimit = require("express-rate-limit");
const config = require("./config");
const { logger, httpLogger } = require("./middleware/logger");
const { notFoundHandler, errorHandler } = require("./middleware/error-handler");
const routes = require("./routes");
const realtime = require("./services/realtime");

const app = express();

// ---------------------------------------------------------------------------
// Global Middleware
// ---------------------------------------------------------------------------

app.use(helmet());

app.use(cors({
  origin: config.isDev ? "*" : /\.smartroad\.app$/,
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization"],
  maxAge: 86400,
}));

app.use(express.json({ limit: "100kb" }));

app.use(
  rateLimit({
    windowMs: config.rateLimit.windowMs,
    max: config.rateLimit.maxRequests,
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, error: { code: "RATE_LIMITED", message: "Too many requests" } },
  })
);

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
// Start Server with WebSocket
// ---------------------------------------------------------------------------
const server = http.createServer(app);

// Initialize WebSocket on the same HTTP server
realtime.initialize(server);

server.listen(config.server.port, () => {
  logger.info(`SmartRoad API started on port ${config.server.port} [${config.env}]`);
  logger.info(`GraphHopper URL: ${config.graphhopper.url}`);
  logger.info(`WebSocket available at ws://localhost:${config.server.port}/ws`);
});

module.exports = app;
