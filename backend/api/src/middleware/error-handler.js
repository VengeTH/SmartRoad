/**
 * SmartRoad Backend — Global Error Handler
 * Catches all thrown/next(err) errors and returns consistent JSON responses.
 */
const { logger } = require("./logger");

/**
 * Custom application error with HTTP status code.
 */
class AppError extends Error {
  constructor(message, statusCode = 500, code = "INTERNAL_ERROR", details = null) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
  }
}

/**
 * 404 handler — must be registered after all routes.
 */
function notFoundHandler(req, res, next) {
  next(new AppError(`Route not found: ${req.method} ${req.originalUrl}`, 404, "NOT_FOUND"));
}

/**
 * Global error handler — catches everything.
 */
function errorHandler(err, req, res, _next) {
  const statusCode = err.statusCode || 500;
  const code = err.code || "INTERNAL_ERROR";
  const message = statusCode === 500 ? "An unexpected error occurred" : err.message;

  if (statusCode >= 500) {
    logger.error(`${req.method} ${req.originalUrl} — ${err.message}`, {
      stack: err.stack,
      code,
    });
  } else {
    logger.warn(`${req.method} ${req.originalUrl} — ${err.message}`, { code });
  }

  res.status(statusCode).json({
    success: false,
    error: {
      code,
      message,
      ...(err.details && { details: err.details }),
    },
  });
}

module.exports = { AppError, notFoundHandler, errorHandler };
