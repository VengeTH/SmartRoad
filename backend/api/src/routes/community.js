/**
 * SmartRoad Backend — Community Routes
 * Comments, likes, and ratings for hazards and places.
 *
 * POST   /api/community/comments        — Add comment
 * GET    /api/community/comments        — List comments (query: parentType, parentId)
 * PUT    /api/community/comments/:id    — Update comment
 * DELETE /api/community/comments/:id    — Delete comment
 * POST   /api/community/likes/toggle    — Toggle like
 * GET    /api/community/likes/count     — Get like count
 * POST   /api/community/ratings         — Set rating
 * GET    /api/community/ratings/summary — Get rating summary
 * GET    /api/community/ratings/mine    — Get my rating
 */
const express = require("express");
const communityService = require("../services/community-service");
const { requireAuth, optionalAuth } = require("../middleware/auth");
const realtime = require("../services/realtime");

const router = express.Router();

// ── Comments ──────────────────────────────────────────────────────────────

router.post("/comments", requireAuth, (req, res) => {
  const { parentType, parentId, text } = req.body;
  const comment = communityService.createComment({
    parentType, parentId, userId: req.user.id, text, userName: req.user.name,
  });
  realtime.notifyCommentAdded(parentType || "hazard", parentId, comment);
  res.status(201).json({ success: true, data: comment });
});

router.get("/comments", optionalAuth, (req, res) => {
  const { parentType, parentId } = req.query;
  if (!parentId) return res.status(400).json({ success: false, error: { code: "VALIDATION_ERROR", message: "parentId required" } });
  const data = communityService.getComments(parentType || "hazard", parentId);
  res.json({ success: true, data, count: data.length });
});

router.put("/comments/:id", requireAuth, (req, res) => {
  const { text } = req.body;
  const comment = communityService.updateComment(req.params.id, req.user.id, text);
  res.json({ success: true, data: comment });
});

router.delete("/comments/:id", requireAuth, (req, res) => {
  communityService.deleteComment(req.params.id, req.user.id);
  res.json({ success: true });
});

// ── Likes ─────────────────────────────────────────────────────────────────

router.post("/likes/toggle", requireAuth, (req, res) => {
  const { parentType, parentId } = req.body;
  if (!parentId) return res.status(400).json({ success: false, error: { code: "VALIDATION_ERROR", message: "parentId required" } });
  const result = communityService.toggleLike(parentType || "hazard", parentId, req.user.id);
  res.json({ success: true, ...result, count: communityService.getLikeCount(parentType || "hazard", parentId) });
});

router.get("/likes/count", (req, res) => {
  const { parentType, parentId } = req.query;
  if (!parentId) return res.status(400).json({ success: false, error: { code: "VALIDATION_ERROR", message: "parentId required" } });
  const count = communityService.getLikeCount(parentType || "hazard", parentId);
  res.json({ success: true, count });
});

// ── Ratings ───────────────────────────────────────────────────────────────

router.post("/ratings", requireAuth, (req, res) => {
  const { parentType, parentId, rating } = req.body;
  if (!parentId || !rating) return res.status(400).json({ success: false, error: { code: "VALIDATION_ERROR", message: "parentId and rating required" } });
  communityService.setRating(parentType || "hazard", parentId, req.user.id, rating);
  const summary = communityService.getRatingSummary(parentType || "hazard", parentId);
  realtime.notifyRatingChanged(parentType || "hazard", parentId, summary);
  res.json({ success: true, ...summary });
});

router.get("/ratings/summary", (req, res) => {
  const { parentType, parentId } = req.query;
  if (!parentId) return res.status(400).json({ success: false, error: { code: "VALIDATION_ERROR", message: "parentId required" } });
  const summary = communityService.getRatingSummary(parentType || "hazard", parentId);
  res.json({ success: true, ...summary });
});

router.get("/ratings/mine", requireAuth, (req, res) => {
  const { parentType, parentId } = req.query;
  if (!parentId) return res.status(400).json({ success: false, error: { code: "VALIDATION_ERROR", message: "parentId required" } });
  const rating = communityService.getUserRating(parentType || "hazard", parentId, req.user.id);
  res.json({ success: true, rating });
});

module.exports = router;
