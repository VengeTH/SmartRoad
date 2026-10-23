package handlers

import (
	"net/http"
	"strconv"

	"smartroad-api/internal/services"
	"smartroad-api/internal/utils"
)

type WeatherHandler struct {
	service *services.WeatherService
}

func NewWeatherHandler(service *services.WeatherService) *WeatherHandler {
	return &WeatherHandler{service: service}
}

func (h *WeatherHandler) HandleCurrent(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	q := r.URL.Query()
	latStr := q.Get("lat")
	lonStr := q.Get("lon")
	if lonStr == "" {
		lonStr = q.Get("lng")
	}

	lat, err1 := strconv.ParseFloat(latStr, 64)
	lon, err2 := strconv.ParseFloat(lonStr, 64)
	if err1 != nil || err2 != nil {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "lat and lon required")
		return
	}

	data, err := h.service.GetCurrentWeather(lat, lon)
	if err != nil {
		utils.Error(w, http.StatusServiceUnavailable, "WEATHER_UNAVAILABLE", "Weather data unavailable")
		return
	}

	utils.Success(w, http.StatusOK, data)
}

func (h *WeatherHandler) HandleAlerts(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	q := r.URL.Query()
	latStr := q.Get("lat")
	lonStr := q.Get("lon")
	if lonStr == "" {
		lonStr = q.Get("lng")
	}

	lat, err1 := strconv.ParseFloat(latStr, 64)
	lon, err2 := strconv.ParseFloat(lonStr, 64)
	if err1 != nil || err2 != nil {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "lat and lon required")
		return
	}

	alerts, err := h.service.GetWeatherAlerts(lat, lon)
	if err != nil {
		utils.Success(w, http.StatusOK, []interface{}{})
		return
	}

	utils.Success(w, http.StatusOK, alerts)
}
