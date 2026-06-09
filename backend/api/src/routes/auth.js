/**
 * SmartRoad Backend — Authentication Routes
 * POST /api/auth/register — Create account
 * POST /api/auth/login    — Sign in
 * GET  /api/auth/me       — Current user (requires auth)
 */
const express = require("express");
const authService = require("../services/auth-service");
const { requireAuth } = require("../middleware/auth");
const { AppError } = require("../middleware/error-handler");

const router = express.Router();

router.post("/register", async (req, res, next) => {
  try {
    const { email, password, name } = req.body;
    const result = await authService.register({ email, password, name });
    res.status(201).json({ success: true, ...result });
  } catch (err) { next(err); }
});

router.post("/login", async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const result = await authService.login({ email, password });
    res.json({ success: true, ...result });
  } catch (err) { next(err); }
});

router.get("/me", requireAuth, (req, res) => {
  const user = authService.getUserById(req.user.id);
  if (!user) return next(new AppError("User not found", 404, "NOT_FOUND"));
  res.json({ success: true, user });
});

module.exports = router;
