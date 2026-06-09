/**
 * SmartRoad Backend — Profile Routes
 * GET  /api/profile       — Get own profile
 * PUT  /api/profile       — Update own profile
 */
const express = require("express");
const profileService = require("../services/profile-service");
const { requireAuth } = require("../middleware/auth");
const { AppError } = require("../middleware/error-handler");

const router = express.Router();

router.get("/", requireAuth, (req, res) => {
  const profile = profileService.getProfile(req.user.id);
  if (!profile) return next(new AppError("Profile not found", 404, "NOT_FOUND"));
  res.json({ success: true, data: profile });
});

router.put("/", requireAuth, (req, res) => {
  const { name, photoUrl } = req.body;
  const profile = profileService.updateProfile(req.user.id, { name, photoUrl });
  res.json({ success: true, data: profile });
});

module.exports = router;
