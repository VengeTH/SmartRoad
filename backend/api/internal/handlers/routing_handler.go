package handlers

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"smartroad-api/internal/models"
	"smartroad-api/internal/services"
	"smartroad-api/internal/utils"
)

type RoutingHandler struct {
	service *services.RoutingService
}

func NewRoutingHandler(service *services.RoutingService) *RoutingHandler {
	return &RoutingHandler{service: service}
}

func (h *RoutingHandler) HandleRoute(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	var req models.RouteRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid request body")
		return
	}

	// Validate coordinates
	if req.Start.Lat == 0 && req.Start.Lon == 0 {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "start.lat and start.lon (numbers) are required")
		return
	}
	if req.End.Lat == 0 && req.End.Lon == 0 {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "end.lat and end.lon (numbers) are required")
		return
	}
	if req.Start.Lat < -90 || req.Start.Lat > 90 || req.Start.Lon < -180 || req.Start.Lon > 180 {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "start coordinates out of range")
		return
	}
	if req.End.Lat < -90 || req.End.Lat > 90 || req.End.Lon < -180 || req.End.Lon > 180 {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "end coordinates out of range")
		return
	}

	if req.Vehicle == "" {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "vehicle is required")
		return
	}

	validVehicle := false
	for _, v := range services.ValidVehicles {
		if v == req.Vehicle {
			validVehicle = true
			break
		}
	}
	if !validVehicle {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "invalid vehicle. Valid: "+strings.Join(services.ValidVehicles, ", "))
		return
	}

	route, isFallback, err := h.service.CalculateRoute(req)
	if err != nil {
		utils.Error(w, http.StatusInternalServerError, "ROUTING_FAILED", err.Error())
		return
	}

	if isFallback {
		utils.SuccessWithNote(w, http.StatusOK, route, "Fallback route (GraphHopper unavailable)")
		return
	}

	utils.Success(w, http.StatusOK, route)
}

func (h *RoutingHandler) HandleVehicles(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	var list []models.VehicleTypeInfo
	for _, v := range services.ValidVehicles {
		label := strings.ReplaceAll(v, "_", " ")
		words := strings.Fields(label)
		for i, w := range words {
			if len(w) > 0 {
				words[i] = strings.ToUpper(w[:1]) + w[1:]
			}
		}
		list = append(list, models.VehicleTypeInfo{
			ID:    v,
			Label: strings.Join(words, " "),
		})
	}

	utils.Success(w, http.StatusOK, list)
}

func (h *RoutingHandler) HandleHealth(w http.ResponseWriter, r *http.Request) {
	utils.JSON(w, http.StatusOK, map[string]interface{}{
		"status":    "ok",
		"service":   "routing",
		"timestamp": time.Now().Format(time.RFC3339),
	})
}
