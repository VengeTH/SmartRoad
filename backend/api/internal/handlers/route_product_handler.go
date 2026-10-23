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

type RouteProductHandler struct {
	service *services.RouteProductService
}

func NewRouteProductHandler(service *services.RouteProductService) *RouteProductHandler {
	return &RouteProductHandler{service: service}
}

func (h *RouteProductHandler) HandleSave(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	user := middleware.GetUserFromContext(r.Context())
	userID := "anonymous"
	if user != nil {
		userID = user.ID
	}

	var req models.SaveRouteRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid body")
		return
	}

	route, err := h.service.SaveRoute(userID, req)
	if err != nil {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Valid name and geometry coordinates required")
		return
	}

	utils.Success(w, http.StatusCreated, route)
}

func (h *RouteProductHandler) HandleDiscover(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	q := r.URL.Query()
	lat, _ := strconv.ParseFloat(q.Get("lat"), 64)
	lng, _ := strconv.ParseFloat(q.Get("lng"), 64)
	radius, _ := strconv.ParseFloat(q.Get("radius_meters"), 64)
	limit, _ := strconv.Atoi(q.Get("limit"))

	var tags []string
	if rawTags := q.Get("tags"); rawTags != "" {
		tags = strings.Split(rawTags, ",")
	}

	filter := models.DiscoverRoutesFilter{
		Lat:          lat,
		Lng:          lng,
		RadiusMeters: radius,
		VehicleType:  q.Get("vehicle_type"),
		Tags:         tags,
		Limit:        limit,
		Sort:         q.Get("sort"),
	}

	routes := h.service.DiscoverRoutes(filter)
	utils.JSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"routes":  routes,
		"count":   len(routes),
	})
}

func (h *RouteProductHandler) HandleRouteByID(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	path := strings.TrimPrefix(r.URL.Path, "/api/v1/routes/")
	id := strings.Split(path, "/")[0]

	route, err := h.service.GetRouteByID(id)
	if err != nil {
		utils.Error(w, http.StatusNotFound, "NOT_FOUND", "Route not found")
		return
	}

	utils.Success(w, http.StatusOK, route)
}
