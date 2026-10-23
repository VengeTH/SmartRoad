package handlers

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"smartroad-api/internal/middleware"
	"smartroad-api/internal/models"
	"smartroad-api/internal/services"
	"smartroad-api/internal/utils"
	"smartroad-api/internal/websocket"
)

type HazardHandler struct {
	service *services.HazardService
	hub     *websocket.Hub
}

func NewHazardHandler(service *services.HazardService, hub *websocket.Hub) *HazardHandler {
	return &HazardHandler{service: service, hub: hub}
}

func (h *HazardHandler) HandleHazards(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		q := r.URL.Query()
		limit, _ := strconv.Atoi(q.Get("limit"))
		if limit <= 0 {
			limit = 50
		}
		offset, _ := strconv.Atoi(q.Get("offset"))

		filter := models.HazardFilter{
			Limit:    limit,
			Offset:   offset,
			Type:     q.Get("type"),
			Severity: q.Get("severity"),
			UserID:   q.Get("userId"),
		}

		list, total := h.service.GetHazards(filter)
		utils.JSON(w, http.StatusOK, map[string]interface{}{
			"success": true,
			"data":    list,
			"total":   total,
		})

	case http.MethodPost:
		user := middleware.GetUserFromContext(r.Context())
		if user == nil {
			utils.Error(w, http.StatusUnauthorized, "AUTH_REQUIRED", "Authentication required")
			return
		}

		var req models.CreateHazardRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid request body")
			return
		}

		hazard, err := h.service.CreateHazard(user.ID, req)
		if err != nil {
			utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "type, description, severity, latitude, longitude are required")
			return
		}

		if h.hub != nil {
			h.hub.Broadcast("hazards:all", map[string]interface{}{
				"event":  "created",
				"hazard": hazard,
			})
		}

		utils.Success(w, http.StatusCreated, hazard)

	default:
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
	}
}

func (h *HazardHandler) HandleNearby(w http.ResponseWriter, r *http.Request) {
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

	radiusKm, _ := strconv.ParseFloat(q.Get("radiusKm"), 64)
	if radiusKm <= 0 {
		radiusKm = 5.0
	}

	data := h.service.GetNearbyHazards(lat, lng, radiusKm)
	utils.JSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    data,
		"count":   len(data),
	})
}

func (h *HazardHandler) HandleBounds(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	q := r.URL.Query()
	minLat, err1 := strconv.ParseFloat(q.Get("minLat"), 64)
	maxLat, err2 := strconv.ParseFloat(q.Get("maxLat"), 64)
	minLng, err3 := strconv.ParseFloat(q.Get("minLng"), 64)
	maxLng, err4 := strconv.ParseFloat(q.Get("maxLng"), 64)

	if err1 != nil || err2 != nil || err3 != nil || err4 != nil {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "minLat, maxLat, minLng, maxLng required")
		return
	}

	data := h.service.GetHazardsInBounds(minLat, maxLat, minLng, maxLng)
	utils.JSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    data,
		"count":   len(data),
	})
}

func (h *HazardHandler) HandleHazardByID(w http.ResponseWriter, r *http.Request) {
	// Extract ID from path: /api/hazards/{id}
	path := strings.TrimPrefix(r.URL.Path, "/api/hazards/")
	id := strings.Split(path, "/")[0]

	if id == "" || id == "nearby" || id == "bounds" {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid hazard ID")
		return
	}

	switch r.Method {
	case http.MethodGet:
		hazard, err := h.service.GetHazardByID(id)
		if err != nil {
			utils.Error(w, http.StatusNotFound, "NOT_FOUND", "Hazard not found")
			return
		}
		utils.Success(w, http.StatusOK, hazard)

	case http.MethodPut:
		user := middleware.GetUserFromContext(r.Context())
		if user == nil {
			utils.Error(w, http.StatusUnauthorized, "AUTH_REQUIRED", "Authentication required")
			return
		}

		var req models.UpdateHazardRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid body")
			return
		}

		hazard, err := h.service.UpdateHazard(id, user.ID, req)
		if err != nil {
			if errors.Is(err, services.ErrHazardNotFound) {
				utils.Error(w, http.StatusNotFound, "NOT_FOUND", "Hazard not found")
				return
			}
			if errors.Is(err, services.ErrUnauthorized) {
				utils.Error(w, http.StatusForbidden, "FORBIDDEN", "Not authorized")
				return
			}
			utils.Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to update hazard")
			return
		}

		if h.hub != nil {
			h.hub.Broadcast("hazards:all", map[string]interface{}{
				"event":  "updated",
				"hazard": hazard,
			})
		}

		utils.Success(w, http.StatusOK, hazard)

	case http.MethodDelete:
		user := middleware.GetUserFromContext(r.Context())
		if user == nil {
			utils.Error(w, http.StatusUnauthorized, "AUTH_REQUIRED", "Authentication required")
			return
		}

		err := h.service.DeleteHazard(id, user.ID)
		if err != nil {
			if errors.Is(err, services.ErrUnauthorized) {
				utils.Error(w, http.StatusForbidden, "FORBIDDEN", "Not authorized")
				return
			}
			utils.Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to delete hazard")
			return
		}

		utils.Success(w, http.StatusOK, map[string]bool{"deleted": true})

	default:
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
	}
}
