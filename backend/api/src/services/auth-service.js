/**
 * SmartRoad Backend — Authentication Service
 * Handles user registration, login, and token management.
 * Uses in-memory store initially; PostgreSQL integration ready.
 */
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const { v4: uuidv4 } = require("uuid");
const config = require("../config");
const { AppError } = require("../middleware/error-handler");
const { logger } = require("../middleware/logger");

// In-memory user store (schema: SmartRoad.users)
// Replace with PostgreSQL queries when backend DB is deployed.
const users = new Map();

// Demo seed users
_seedDemoUsers();

function _seedDemoUsers() {
  const demoId = uuidv4();
  users.set("demo@smartroad.app", {
    id: demoId,
    email: "demo@smartroad.app",
    name: "Demo User",
    password: bcrypt.hashSync("DemoPass123!", 10),
    createdAt: new Date().toISOString(),
  });
}

/**
 * Register a new user.
 */
async function register({ email, password, name }) {
  if (!email || !password || !name) {
    throw new AppError("Email, password, and name are required", 400, "VALIDATION_ERROR");
  }
  if (users.has(email)) {
    throw new AppError("Email already registered", 409, "EMAIL_EXISTS");
  }
  if (password.length < 6) {
    throw new AppError("Password must be at least 6 characters", 400, "VALIDATION_ERROR");
  }

  const id = uuidv4();
  const hashed = await bcrypt.hash(password, 10);
  const user = { id, email, name, password: hashed, createdAt: new Date().toISOString() };
  users.set(email, user);

  const token = _generateToken(user);
  logger.info(`User registered: ${email}`);
  return { user: _sanitize(user), token };
}

/**
 * Login with email and password.
 */
async function login({ email, password }) {
  if (!email || !password) {
    throw new AppError("Email and password are required", 400, "VALIDATION_ERROR");
  }

  const user = users.get(email);
  if (!user) {
    throw new AppError("Invalid email or password", 401, "INVALID_CREDENTIALS");
  }

  const valid = await bcrypt.compare(password, user.password);
  if (!valid) {
    throw new AppError("Invalid email or password", 401, "INVALID_CREDENTIALS");
  }

  const token = _generateToken(user);
  logger.info(`User logged in: ${email}`);
  return { user: _sanitize(user), token };
}

/**
 * Get user by ID.
 */
function getUserById(id) {
  for (const user of users.values()) {
    if (user.id === id) return _sanitize(user);
  }
  return null;
}

function _generateToken(user) {
  return jwt.sign(
    { sub: user.id, email: user.email, name: user.name },
    config.jwt.secret,
    { expiresIn: config.jwt.expiresIn }
  );
}

function _sanitize(user) {
  return { id: user.id, email: user.email, name: user.name, createdAt: user.createdAt };
}

module.exports = { register, login, getUserById };
