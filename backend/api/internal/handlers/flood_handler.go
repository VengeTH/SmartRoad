package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"smartroad-api/internal/middleware"
	"smartroad-api/internal/models"
	"smartroad-api/internal/services"
	"smartroad-api/internal/utils"
)

type FloodHandler struct {
	service *services.FloodService
}

func NewFloodHandler(service *services.FloodService) *FloodHandler {
	return &FloodHandler{service: service}
}

func (h *FloodHandler) HandleFloodZones(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		sev := r.URL.Query().Get("severity")
		list := h.service.GetZones(sev)
		utils.JSON(w, http.StatusOK, map[string]interface{}{
			"success": true,
			"data":    list,
			"count":   len(list),
		})

	case http.MethodPost:
		user := middleware.GetUserFromContext(r.Context())
		if user == nil {
			utils.Error(w, http.StatusUnauthorized, "AUTH_REQUIRED", "Authentication required")
			return
		}

		var req models.CreateFloodZoneRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid body")
			return
		}

		zone, err := h.service.CreateZone(req)
		if err != nil {
			utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "name, lat, lng required")
			return
		}

		utils.Success(w, http.StatusCreated, zone)

	default:
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
	}
}

func (h *FloodHandler) HandleNearby(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	q := r.URL.Query()
	lat, err1 := strconv.ParseFloat(q.Get("lat"), 64)
	lng, err2 := strconv.ParseFloat(q.Get("lng"), 64)
	if err1 != nil || err2 != nil {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "lat and lng required")
		return
	}

	data := h.service.GetNearby(lat, lng)
	utils.JSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    data,
		"count":   len(data),
	})
}
