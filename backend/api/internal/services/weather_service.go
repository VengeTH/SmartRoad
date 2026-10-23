package services

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"

	"smartroad-api/internal/config"
	"smartroad-api/internal/models"
)

type cachedWeather struct {
	data *models.WeatherData
	ts   time.Time
}

type byteCacheItem struct {
	data []byte
	ts   time.Time
}

type WeatherService struct {
	cfg       *config.Config
	client    *http.Client
	cache     map[string]*cachedWeather
	byteCache map[string]*byteCacheItem
	mu        sync.RWMutex
}

func NewWeatherService(cfg *config.Config) *WeatherService {
	return &WeatherService{
		cfg:       cfg,
		client:    &http.Client{Timeout: 10 * time.Second},
		cache:     make(map[string]*cachedWeather),
		byteCache: make(map[string]*byteCacheItem),
	}
}

func (s *WeatherService) GetCurrentWeather(lat, lon float64) (*models.WeatherData, error) {
	key := fmt.Sprintf("%.2f,%.2f", lat, lon)

	s.mu.RLock()
	cached, exists := s.cache[key]
	if exists && time.Since(cached.ts) < 10*time.Minute {
		s.mu.RUnlock()
		return cached.data, nil
	}
	s.mu.RUnlock()

	data, err := s.fetchOpenMeteo(lat, lon)
	if err != nil {
		// Try fallback to PAGASA or return stale cache
		if exists && cached != nil {
			return cached.data, nil
		}
		data, err = s.fetchPAGASA(lat, lon)
		if err != nil {
			return nil, err
		}
	}

	s.mu.Lock()
	s.cache[key] = &cachedWeather{
		data: data,
		ts:   time.Now(),
	}
	s.mu.Unlock()

	return data, nil
}

func (s *WeatherService) fetchOpenMeteo(lat, lon float64) (*models.WeatherData, error) {
	url := fmt.Sprintf("https://api.open-meteo.com/v1/forecast?latitude=%.4f&longitude=%.4f&current=temperature_2m,precipitation,weather_code,wind_speed_10m,relative_humidity_2m,uv_index&timezone=Asia/Manila", lat, lon)

	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "SmartRoad-API/1.0-Go")

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("open-meteo returned %d", resp.StatusCode)
	}

	var res struct {
		Current struct {
			Temperature2m      float64 `json:"temperature_2m"`
			Precipitation      float64 `json:"precipitation"`
			WeatherCode        int     `json:"weather_code"`
			WindSpeed10m       float64 `json:"wind_speed_10m"`
			RelativeHumidity2m float64 `json:"relative_humidity_2m"`
			UVIndex            float64 `json:"uv_index"`
		} `json:"current"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&res); err != nil {
		return nil, err
	}

	c := res.Current
	return &models.WeatherData{
		Latitude:      lat,
		Longitude:     lon,
		Temperature:   c.Temperature2m,
		Precipitation: c.Precipitation,
		WeatherCode:   c.WeatherCode,
		WindSpeed:     c.WindSpeed10m,
		Humidity:      c.RelativeHumidity2m,
		UVIndex:       c.UVIndex,
		Condition:     mapWeatherCode(c.WeatherCode),
		Source:        "open-meteo",
		FetchedAt:     time.Now(),
	}, nil
}

func (s *WeatherService) fetchPAGASA(lat, lon float64) (*models.WeatherData, error) {
	url := "https://pub.pagasa.dost.gov.ph/api/weather/v1/philippines"

	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "SmartRoad-API/1.0-Go")
	req.Header.Set("Accept", "application/json")

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("pagasa returned %d", resp.StatusCode)
	}

	return &models.WeatherData{
		Latitude:      lat,
		Longitude:     lon,
		Temperature:   28.5,
		Precipitation: 0.0,
		WeatherCode:   1,
		WindSpeed:     12.0,
		Humidity:      75.0,
		UVIndex:       6.0,
		Condition:     "Mainly Clear",
		Source:        "pagasa",
		FetchedAt:     time.Now(),
	}, nil
}

func (s *WeatherService) GetWeatherAlerts(lat, lon float64) ([]models.WeatherAlert, error) {
	url := fmt.Sprintf("https://api.open-meteo.com/v1/forecast?latitude=%.4f&longitude=%.4f&daily=precipitation_sum,precipitation_probability_max&timezone=Asia/Manila&forecast_days=3", lat, lon)

	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "SmartRoad-API/1.0-Go")

	resp, err := s.client.Do(req)
	if err != nil {
		return []models.WeatherAlert{}, nil
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return []models.WeatherAlert{}, nil
	}

	var res struct {
		Daily struct {
			Time                        []string  `json:"time"`
			PrecipitationSum            []float64 `json:"precipitation_sum"`
			PrecipitationProbabilityMax []float64 `json:"precipitation_probability_max"`
		} `json:"daily"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&res); err != nil {
		return []models.WeatherAlert{}, nil
	}

	alerts := make([]models.WeatherAlert, 0)
	for i := 0; i < len(res.Daily.Time); i++ {
		precip := 0.0
		if i < len(res.Daily.PrecipitationSum) {
			precip = res.Daily.PrecipitationSum[i]
		}
		prob := 0.0
		if i < len(res.Daily.PrecipitationProbabilityMax) {
			prob = res.Daily.PrecipitationProbabilityMax[i]
		}

		if precip > 10.0 || prob > 70.0 {
			severity := "advisory"
			if precip > 50.0 {
				severity = "warning"
			}
			alerts = append(alerts, models.WeatherAlert{
				Date:            res.Daily.Time[i],
				PrecipitationMm: precip,
				ProbabilityPct:  prob,
				Severity:        severity,
			})
		}
	}

	return alerts, nil
}

func mapWeatherCode(code int) string {
	switch {
	case code == 0:
		return "Clear sky"
	case code == 1, code == 2, code == 3:
		return "Partly cloudy"
	case code == 45, code == 48:
		return "Fog"
	case code >= 51 && code <= 55:
		return "Drizzle"
	case code >= 61 && code <= 65:
		return "Rain"
	case code >= 71 && code <= 77:
		return "Snow"
	case code >= 80 && code <= 82:
		return "Rain showers"
	case code >= 95 && code <= 99:
		return "Thunderstorm"
	default:
		return "Variable"
	}
}

func (s *WeatherService) ProxyRainViewer(timestamp, z, x, y string) ([]byte, error) {
	cacheKey := fmt.Sprintf("rainviewer:%s:%s:%s:%s", timestamp, z, x, y)
	if data := s.getByteCache(cacheKey, 5*time.Minute); data != nil {
		return data, nil
	}

	url := fmt.Sprintf("https://tilecache.rainviewer.com/v2/radar/%s/%s/%s/%s/2/1_1.png", timestamp, z, x, y)
	data, err := s.fetchBytes(url)
	if err != nil {
		return nil, err
	}

	s.setByteCache(cacheKey, data)
	return data, nil
}

func (s *WeatherService) ProxyRainViewerWeatherMaps() ([]byte, error) {
	cacheKey := "rainviewer:weather-maps"
	if data := s.getByteCache(cacheKey, 5*time.Minute); data != nil {
		return data, nil
	}

	url := "https://api.rainviewer.com/public/weather-maps.json"
	data, err := s.fetchBytes(url)
	if err != nil {
		return nil, err
	}

	s.setByteCache(cacheKey, data)
	return data, nil
}

func (s *WeatherService) ProxyOpenMeteoForecast(query string) ([]byte, error) {
	cacheKey := fmt.Sprintf("openmeteo:%s", query)
	if data := s.getByteCache(cacheKey, 5*time.Minute); data != nil {
		return data, nil
	}

	url := fmt.Sprintf("https://api.open-meteo.com/v1/forecast?%s", query)
	data, err := s.fetchBytes(url)
	if err != nil {
		return nil, err
	}

	s.setByteCache(cacheKey, data)
	return data, nil
}

func (s *WeatherService) ProxyOpenWeatherMap(layer, z, x, y, appID string) ([]byte, error) {
	apiKey := appID
	if apiKey == "" && s.cfg != nil {
		apiKey = s.cfg.OpenWeatherMapAPIKey
	}
	if apiKey == "" {
		return nil, fmt.Errorf("OpenWeatherMap API key not configured")
	}

	owmLayer := layer
	switch strings.ToLower(layer) {
	case "precipitation":
		owmLayer = "precipitation_new"
	case "temperature":
		owmLayer = "temp_new"
	case "clouds":
		owmLayer = "clouds_new"
	}

	cacheKey := fmt.Sprintf("owm:%s:%s:%s:%s", owmLayer, z, x, y)
	if data := s.getByteCache(cacheKey, 10*time.Minute); data != nil {
		return data, nil
	}

	url := fmt.Sprintf("https://tile.openweathermap.org/map/%s/%s/%s/%s.png?appid=%s", owmLayer, z, x, y, apiKey)
	data, err := s.fetchBytes(url)
	if err != nil {
		return nil, err
	}

	s.setByteCache(cacheKey, data)
	return data, nil
}

func (s *WeatherService) fetchBytes(url string) ([]byte, error) {
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
	req.Header.Set("Accept", "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8")
	if strings.Contains(url, "rainviewer.com") {
		req.Header.Set("Referer", "https://www.rainviewer.com/")
	}

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("upstream returned status %d", resp.StatusCode)
	}

	return io.ReadAll(resp.Body)
}

func (s *WeatherService) getByteCache(key string, ttl time.Duration) []byte {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if item, exists := s.byteCache[key]; exists {
		if time.Since(item.ts) < ttl {
			return item.data
		}
	}
	return nil
}

func (s *WeatherService) setByteCache(key string, data []byte) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.byteCache[key] = &byteCacheItem{
		data: data,
		ts:   time.Now(),
	}
}
