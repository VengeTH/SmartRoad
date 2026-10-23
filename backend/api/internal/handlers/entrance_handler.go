package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"smartroad-api/internal/middleware"
	"smartroad-api/internal/models"
	"smartroad-api/internal/services"
	"smartroad-api/internal/utils"
)

type EntranceHandler struct {
	service *services.EntranceService
}

func NewEntranceHandler(service *services.EntranceService) *EntranceHandler {
	return &EntranceHandler{service: service}
}

func (h *EntranceHandler) HandleEntrances(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		q := r.URL.Query()
		hoaID := q.Get("hoaId")
		typ := q.Get("type")
		var verifiedPtr *bool
		if q.Has("verified") {
			v := q.Get("verified") == "true"
			verifiedPtr = &v
		}

		data := h.service.GetEntrances(hoaID, typ, verifiedPtr)
		utils.JSON(w, http.StatusOK, map[string]interface{}{
			"success": true,
			"data":    data,
			"count":   len(data),
		})

	case http.MethodPost:
		user := middleware.GetUserFromContext(r.Context())
		if user == nil {
			utils.Error(w, http.StatusUnauthorized, "AUTH_REQUIRED", "Authentication required")
			return
		}

		var req models.CreateEntranceRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid body")
			return
		}

		entrance, err := h.service.CreateEntrance(req)
		if err != nil {
			utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "hoaId, name, lat, lng required")
			return
		}

		utils.Success(w, http.StatusCreated, entrance)

	default:
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
	}
}

func (h *EntranceHandler) HandleNearby(w http.ResponseWriter, r *http.Request) {
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
		radiusKm = 2.0
	}

	data := h.service.GetNearby(lat, lng, radiusKm)
	utils.JSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    data,
		"count":   len(data),
	})
}

func (h *EntranceHandler) HandleVerify(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPut {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	user := middleware.GetUserFromContext(r.Context())
	if user == nil {
		utils.Error(w, http.StatusUnauthorized, "AUTH_REQUIRED", "Authentication required")
		return
	}

	// Path: /api/entrances/{id}/verify
	path := strings.TrimPrefix(r.URL.Path, "/api/entrances/")
	id := strings.TrimSuffix(path, "/verify")

	entrance, err := h.service.VerifyEntrance(id, user.ID)
	if err != nil {
		utils.Error(w, http.StatusNotFound, "NOT_FOUND", "Entrance not found")
		return
	}

	utils.Success(w, http.StatusOK, entrance)
}
