/**
 * SmartRoad Backend — Community Service
 * Handles comments, likes, ratings on hazards and places.
 * In-memory store; ready for PostgreSQL migration.
 */
const { v4: uuidv4 } = require("uuid");
const { AppError } = require("../middleware/error-handler");

// Stores by type
const comments = new Map();    // key: commentId
const likes = new Map();       // key: `${parentType}:${parentId}:${userId}`
const ratings = new Map();     // key: `${parentType}:${parentId}:${userId}`

// ============================================================================
// COMMENTS
// ============================================================================

function createComment({ parentType, parentId, userId, text, userName }) {
  if (!parentId || !text?.trim()) {
    throw new AppError("parentId and text are required", 400, "VALIDATION_ERROR");
  }
  const id = uuidv4();
  const comment = {
    id, parentType: parentType || "hazard", parentId, userId,
    text: text.trim(), userName: userName || "Anonymous",
    createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
  };
  comments.set(id, comment);
  return comment;
}

function getComments(parentType, parentId) {
  return Array.from(comments.values())
    .filter((c) => c.parentType === parentType && c.parentId === parentId)
    .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
}

function updateComment(commentId, userId, text) {
  const comment = comments.get(commentId);
  if (!comment) throw new AppError("Comment not found", 404, "NOT_FOUND");
  if (comment.userId !== userId) throw new AppError("Not authorized", 403, "FORBIDDEN");
  comment.text = text.trim();
  comment.updatedAt = new Date().toISOString();
  return comment;
}

function deleteComment(commentId, userId) {
  const comment = comments.get(commentId);
  if (!comment) return;
  if (comment.userId !== userId) throw new AppError("Not authorized", 403, "FORBIDDEN");
  comments.delete(commentId);
}

// ============================================================================
// LIKES
// ============================================================================

function toggleLike(parentType, parentId, userId) {
  const key = `${parentType}:${parentId}:${userId}`;
  if (likes.has(key)) { likes.delete(key); return { liked: false }; }
  likes.set(key, { parentType, parentId, userId, createdAt: new Date().toISOString() });
  return { liked: true };
}

function getLikeCount(parentType, parentId) {
  return Array.from(likes.values()).filter(
    (l) => l.parentType === parentType && l.parentId === parentId
  ).length;
}

function hasLiked(parentType, parentId, userId) {
  return likes.has(`${parentType}:${parentId}:${userId}`);
}

// ============================================================================
// RATINGS
// ============================================================================

function setRating(parentType, parentId, userId, rating) {
  if (rating < 1 || rating > 5) throw new AppError("Rating must be 1-5", 400, "VALIDATION_ERROR");
  const key = `${parentType}:${parentId}:${userId}`;
  ratings.set(key, { parentType, parentId, userId, rating, createdAt: new Date().toISOString() });
  return { rating };
}

function getRatingSummary(parentType, parentId) {
  const all = Array.from(ratings.values()).filter(
    (r) => r.parentType === parentType && r.parentId === parentId
  );
  if (all.length === 0) return { avgRating: 0, ratingsCount: 0 };
  const total = all.reduce((s, r) => s + r.rating, 0);
  return { avgRating: Math.round((total / all.length) * 100) / 100, ratingsCount: all.length };
}

function getUserRating(parentType, parentId, userId) {
  const r = ratings.get(`${parentType}:${parentId}:${userId}`);
  return r ? r.rating : null;
}

module.exports = {
  createComment, getComments, updateComment, deleteComment,
  toggleLike, getLikeCount, hasLiked,
  setRating, getRatingSummary, getUserRating,
};
