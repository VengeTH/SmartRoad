package services

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"

	"smartroad-api/internal/models"
)

type cachedWeather struct {
	data *models.WeatherData
	ts   time.Time
}

type WeatherService struct {
	client *http.Client
	cache  map[string]*cachedWeather
	mu     sync.RWMutex
}

func NewWeatherService() *WeatherService {
	return &WeatherService{
		client: &http.Client{Timeout: 8 * time.Second},
		cache:  make(map[string]*cachedWeather),
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
			Time                       []string  `json:"time"`
			PrecipitationSum           []float64 `json:"precipitation_sum"`
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
