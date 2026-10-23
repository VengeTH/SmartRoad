package handlers

import (
	"encoding/json"
	"net/http"

	"smartroad-api/internal/middleware"
	"smartroad-api/internal/models"
	"smartroad-api/internal/services"
	"smartroad-api/internal/utils"
)

type ProfileHandler struct {
	service *services.ProfileService
}

func NewProfileHandler(service *services.ProfileService) *ProfileHandler {
	return &ProfileHandler{service: service}
}

func (h *ProfileHandler) HandleProfile(w http.ResponseWriter, r *http.Request) {
	user := middleware.GetUserFromContext(r.Context())
	if user == nil {
		utils.Error(w, http.StatusUnauthorized, "AUTH_REQUIRED", "Authentication required")
		return
	}

	switch r.Method {
	case http.MethodGet:
		p, err := h.service.GetProfile(user.ID)
		if err != nil {
			utils.Error(w, http.StatusNotFound, "NOT_FOUND", "Profile not found")
			return
		}
		utils.Success(w, http.StatusOK, p)

	case http.MethodPut:
		var req models.UpdateProfileRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid body")
			return
		}
		p, err := h.service.UpdateProfile(user.ID, req)
		if err != nil {
			utils.Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to update profile")
			return
		}
		utils.Success(w, http.StatusOK, p)

	default:
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
	}
}
