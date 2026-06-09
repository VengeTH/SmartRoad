/**
 * SmartRoad Backend — Profile Service
 * Manages user profiles (SmartRoad.profiles).
 * In-memory store; ready for PostgreSQL migration.
 */
const { AppError } = require("../middleware/error-handler");

const profiles = new Map();

// Seed demo profile
profiles.set("demo-user-id", {
  id: "demo-user-id",
  name: "Demo User",
  email: "demo@smartroad.app",
  photoUrl: null,
  reporterLevel: "Novice",
  validReportsCount: 0,
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString(),
});

/**
 * Get profile by user ID.
 */
function getProfile(userId) {
  return profiles.get(userId) || null;
}

/**
 * Create or update profile.
 */
function upsertProfile(userId, data) {
  const existing = profiles.get(userId) || {
    id: userId,
    createdAt: new Date().toISOString(),
  };

  const updated = {
    ...existing,
    name: data.name ?? existing.name,
    email: data.email ?? existing.email,
    photoUrl: data.photoUrl !== undefined ? data.photoUrl : existing.photoUrl,
    reporterLevel: data.reporterLevel ?? existing.reporterLevel ?? "Novice",
    updatedAt: new Date().toISOString(),
  };

  profiles.set(userId, updated);
  return updated;
}

/**
 * Update profile fields.
 */
function updateProfile(userId, updates) {
  const existing = profiles.get(userId);
  if (!existing) throw new AppError("Profile not found", 404, "NOT_FOUND");

  Object.assign(existing, updates, { updatedAt: new Date().toISOString() });
  profiles.set(userId, existing);
  return existing;
}

module.exports = { getProfile, upsertProfile, updateProfile };
