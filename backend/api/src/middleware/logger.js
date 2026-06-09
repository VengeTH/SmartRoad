/**
 * SmartRoad Backend — Logging Middleware
 * Uses Winston for structured logging + Morgan for HTTP request logging.
 */
const winston = require("winston");
const morgan = require("morgan");
const config = require("../config");

const logger = winston.createLogger({
  level: config.logging.level,
  format: winston.format.combine(
    winston.format.timestamp({ format: "YYYY-MM-DD HH:mm:ss.SSS" }),
    winston.format.errors({ stack: true }),
    config.isProd
      ? winston.format.json()
      : winston.format.printf(
          ({ timestamp, level, message, ...meta }) =>
            `${timestamp} [${level.toUpperCase()}] ${message} ${
              Object.keys(meta).length ? JSON.stringify(meta) : ""
            }`
        )
  ),
  transports: [
    new winston.transports.Console(),
    ...(config.isProd
      ? [
          new winston.transports.File({ filename: "logs/error.log", level: "error" }),
          new winston.transports.File({ filename: "logs/combined.log" }),
        ]
      : []),
  ],
});

/**
 * HTTP request logging via Morgan (streamed to Winston).
 */
const httpLogger = morgan("short", {
  stream: { write: (msg) => logger.info(msg.trim()) },
  skip: (req) => req.url === "/health",
});

module.exports = { logger, httpLogger };
