package handlers

import (
	"encoding/json"
	"net/http"
	"strings"

	"smartroad-api/internal/middleware"
	"smartroad-api/internal/models"
	"smartroad-api/internal/services"
	"smartroad-api/internal/utils"
)

type HOAHandler struct {
	service *services.HOAService
}

func NewHOAHandler(service *services.HOAService) *HOAHandler {
	return &HOAHandler{service: service}
}

func (h *HOAHandler) HandleHOAs(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	data := h.service.GetHOAs()
	utils.Success(w, http.StatusOK, data)
}

func (h *HOAHandler) HandleRegister(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	user := middleware.GetUserFromContext(r.Context())
	if user == nil {
		utils.Error(w, http.StatusUnauthorized, "AUTH_REQUIRED", "Authentication required")
		return
	}

	var req models.RegisterHOARequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid body")
		return
	}

	hoa, err := h.service.RegisterHOA(user.ID, req)
	if err != nil {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "name required")
		return
	}

	utils.Success(w, http.StatusCreated, hoa)
}

func (h *HOAHandler) HandleHOAByID(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	path := strings.TrimPrefix(r.URL.Path, "/api/hoas/")
	id := strings.Split(path, "/")[0]

	hoa, err := h.service.GetHOAByID(id)
	if err != nil {
		utils.Error(w, http.StatusNotFound, "NOT_FOUND", "HOA not found")
		return
	}

	utils.Success(w, http.StatusOK, hoa)
}
