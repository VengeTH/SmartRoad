package handlers

import (
	"encoding/json"
	"net/http"
	"strings"

	"smartroad-api/internal/middleware"
	"smartroad-api/internal/models"
	"smartroad-api/internal/services"
	"smartroad-api/internal/utils"
	"smartroad-api/internal/websocket"
)

type CommunityHandler struct {
	service *services.CommunityService
	hub     *websocket.Hub
}

func NewCommunityHandler(service *services.CommunityService, hub *websocket.Hub) *CommunityHandler {
	return &CommunityHandler{service: service, hub: hub}
}

func (h *CommunityHandler) HandleComments(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		q := r.URL.Query()
		parentType := q.Get("parentType")
		parentID := q.Get("parentId")
		if parentID == "" {
			utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "parentId required")
			return
		}

		comments := h.service.GetComments(parentType, parentID)
		utils.JSON(w, http.StatusOK, map[string]interface{}{
			"success": true,
			"data":    comments,
			"count":   len(comments),
		})

	case http.MethodPost:
		user := middleware.GetUserFromContext(r.Context())
		if user == nil {
			utils.Error(w, http.StatusUnauthorized, "AUTH_REQUIRED", "Authentication required")
			return
		}

		var req models.CreateCommentRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid body")
			return
		}

		comment, err := h.service.CreateComment(req.ParentType, req.ParentID, user.ID, user.Name, req.Text)
		if err != nil {
			utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "parentId and text are required")
			return
		}

		if h.hub != nil {
			h.hub.Broadcast("community:"+req.ParentID, map[string]interface{}{
				"event":   "comment_added",
				"comment": comment,
			})
		}

		utils.Success(w, http.StatusCreated, comment)

	default:
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
	}
}

func (h *CommunityHandler) HandleCommentByID(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/api/community/comments/")
	id := strings.Split(path, "/")[0]
	if id == "" {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Comment ID required")
		return
	}

	user := middleware.GetUserFromContext(r.Context())
	if user == nil {
		utils.Error(w, http.StatusUnauthorized, "AUTH_REQUIRED", "Authentication required")
		return
	}

	switch r.Method {
	case http.MethodPut:
		var req models.UpdateCommentRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid body")
			return
		}

		comment, err := h.service.UpdateComment(id, user.ID, req.Text)
		if err != nil {
			utils.Error(w, http.StatusNotFound, "NOT_FOUND", "Comment not found or not authorized")
			return
		}
		utils.Success(w, http.StatusOK, comment)

	case http.MethodDelete:
		err := h.service.DeleteComment(id, user.ID)
		if err != nil {
			utils.Error(w, http.StatusForbidden, "FORBIDDEN", "Not authorized")
			return
		}
		utils.Success(w, http.StatusOK, map[string]bool{"deleted": true})

	default:
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
	}
}

func (h *CommunityHandler) HandleLikesToggle(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	user := middleware.GetUserFromContext(r.Context())
	if user == nil {
		utils.Error(w, http.StatusUnauthorized, "AUTH_REQUIRED", "Authentication required")
		return
	}

	var req models.ToggleLikeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.ParentID == "" {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "parentId required")
		return
	}

	liked, count := h.service.ToggleLike(req.ParentType, req.ParentID, user.ID)
	utils.JSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"liked":   liked,
		"count":   count,
	})
}

func (h *CommunityHandler) HandleLikesCount(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	q := r.URL.Query()
	parentType := q.Get("parentType")
	parentID := q.Get("parentId")
	if parentID == "" {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "parentId required")
		return
	}

	count := h.service.GetLikeCount(parentType, parentID)
	utils.JSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"count":   count,
	})
}

func (h *CommunityHandler) HandleRatings(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	user := middleware.GetUserFromContext(r.Context())
	if user == nil {
		utils.Error(w, http.StatusUnauthorized, "AUTH_REQUIRED", "Authentication required")
		return
	}

	var req models.SetRatingRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.ParentID == "" {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "parentId and rating required")
		return
	}

	summary, err := h.service.SetRating(req.ParentType, req.ParentID, user.ID, req.Rating)
	if err != nil {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Rating must be 1-5")
		return
	}

	if h.hub != nil {
		h.hub.Broadcast("community:"+req.ParentID, map[string]interface{}{
			"event":   "rating_changed",
			"summary": summary,
		})
	}

	utils.JSON(w, http.StatusOK, map[string]interface{}{
		"success":      true,
		"avgRating":    summary.AvgRating,
		"ratingsCount": summary.RatingsCount,
	})
}

func (h *CommunityHandler) HandleRatingsSummary(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	q := r.URL.Query()
	parentType := q.Get("parentType")
	parentID := q.Get("parentId")
	if parentID == "" {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "parentId required")
		return
	}

	summary := h.service.GetRatingSummary(parentType, parentID)
	utils.JSON(w, http.StatusOK, map[string]interface{}{
		"success":      true,
		"avgRating":    summary.AvgRating,
		"ratingsCount": summary.RatingsCount,
	})
}

func (h *CommunityHandler) HandleRatingsMine(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	user := middleware.GetUserFromContext(r.Context())
	if user == nil {
		utils.Error(w, http.StatusUnauthorized, "AUTH_REQUIRED", "Authentication required")
		return
	}

	q := r.URL.Query()
	parentType := q.Get("parentType")
	parentID := q.Get("parentId")
	if parentID == "" {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "parentId required")
		return
	}

	rating := h.service.GetUserRating(parentType, parentID, user.ID)
	utils.JSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"rating":  rating,
	})
}
