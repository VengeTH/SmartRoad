package handlers

import (
	"net/http"
	"strconv"
	"strings"

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

func (h *WeatherHandler) HandleOpenMeteoForecast(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	data, err := h.service.ProxyOpenMeteoForecast(r.URL.RawQuery)
	if err != nil {
		utils.Error(w, http.StatusBadGateway, "PROXY_ERROR", err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "public, max-age=300")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(data)
}

func (h *WeatherHandler) HandleRainViewer(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	// Route might be /rainviewer/weather-maps or /rainviewer/{timestamp}/{z}/{x}/{y}
	path := r.URL.Path
	if idx := strings.Index(path, "/rainviewer/"); idx != -1 {
		subpath := path[idx+len("/rainviewer/"):]
		if subpath == "weather-maps" || subpath == "weather-maps.json" {
			data, err := h.service.ProxyRainViewerWeatherMaps()
			if err != nil {
				utils.Error(w, http.StatusBadGateway, "PROXY_ERROR", err.Error())
				return
			}
			w.Header().Set("Content-Type", "application/json; charset=utf-8")
			w.Header().Set("Cache-Control", "public, max-age=300")
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write(data)
			return
		}

		parts := strings.Split(subpath, "/")
		if len(parts) >= 4 {
			timestamp, z, x, y := parts[0], parts[1], parts[2], parts[3]
			y = strings.TrimSuffix(y, ".png")
			data, err := h.service.ProxyRainViewer(timestamp, z, x, y)
			if err != nil {
				utils.Error(w, http.StatusBadGateway, "PROXY_ERROR", err.Error())
				return
			}
			w.Header().Set("Content-Type", "image/png")
			w.Header().Set("Cache-Control", "public, max-age=300")
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write(data)
			return
		}
	}

	utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "invalid rainviewer path")
}

func (h *WeatherHandler) HandleOpenWeatherMap(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	// Format: /openweathermap/{layer}/{z}/{x}/{y}
	path := r.URL.Path
	idx := strings.Index(path, "/openweathermap/")
	if idx == -1 {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "invalid openweathermap path")
		return
	}

	subpath := path[idx+len("/openweathermap/"):]
	parts := strings.Split(subpath, "/")
	if len(parts) < 4 {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "expected /openweathermap/{layer}/{z}/{x}/{y}")
		return
	}

	layer, z, x, y := parts[0], parts[1], parts[2], parts[3]
	y = strings.TrimSuffix(y, ".png")
	appID := r.URL.Query().Get("appid")

	data, err := h.service.ProxyOpenWeatherMap(layer, z, x, y, appID)
	if err != nil {
		utils.Error(w, http.StatusBadGateway, "PROXY_ERROR", err.Error())
		return
	}

	w.Header().Set("Content-Type", "image/png")
	w.Header().Set("Cache-Control", "public, max-age=600")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(data)
}
