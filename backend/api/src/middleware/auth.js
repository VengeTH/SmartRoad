/**
 * SmartRoad Backend — JWT Authentication Middleware
 * Verifies Bearer tokens on protected routes. Populates req.user.
 */
const jwt = require("jsonwebtoken");
const config = require("../config");
const { AppError } = require("./error-handler");

/**
 * Required auth — rejects unauthenticated requests.
 */
function requireAuth(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith("Bearer ")) {
    return next(new AppError("Authentication required", 401, "AUTH_REQUIRED"));
  }

  const token = header.split(" ")[1];
  try {
    const decoded = jwt.verify(token, config.jwt.secret);
    req.user = { id: decoded.sub, email: decoded.email, name: decoded.name };
    next();
  } catch (err) {
    if (err.name === "TokenExpiredError") {
      return next(new AppError("Token expired", 401, "TOKEN_EXPIRED"));
    }
    return next(new AppError("Invalid token", 401, "INVALID_TOKEN"));
  }
}

/**
 * Optional auth — sets req.user if token present, continues regardless.
 */
function optionalAuth(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith("Bearer ")) {
    req.user = null;
    return next();
  }

  const token = header.split(" ")[1];
  try {
    const decoded = jwt.verify(token, config.jwt.secret);
    req.user = { id: decoded.sub, email: decoded.email, name: decoded.name };
  } catch (_) {
    req.user = null;
  }
  next();
}

module.exports = { requireAuth, optionalAuth };
