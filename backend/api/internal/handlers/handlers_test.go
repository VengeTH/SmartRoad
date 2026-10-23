package handlers_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"smartroad-api/internal/config"
	"smartroad-api/internal/handlers"
	"smartroad-api/internal/models"
	"smartroad-api/internal/services"
	"smartroad-api/internal/websocket"
)

func setupTestApp() http.Handler {
	cfg := &config.Config{
		Env:                   "test",
		IsDev:                 true,
		Port:                  "3000",
		GraphHopperURL:        "http://localhost:8989",
		GraphHopperTimeout:    100,
		GraphHopperMaxRetries: 0,
		JWTSecret:             "test-secret",
		JWTExpiresInDays:      1,
		RateLimitWindow:       60000,
		RateLimitMax:          1000,
		LogLevel:              "debug",
		CORSOrigin:            "*",
	}

	authService := services.NewAuthService(cfg)
	profileService := services.NewProfileService()
	hazardService := services.NewHazardService()
	entranceService := services.NewEntranceService()
	floodService := services.NewFloodService()
	hoaService := services.NewHOAService()
	communityService := services.NewCommunityService()
	weatherService := services.NewWeatherService(cfg)
	routingService := services.NewRoutingService(cfg, hazardService, floodService)
	routeProductService := services.NewRouteProductService()
	hub := websocket.GetHub()

	deps := &handlers.AppDependencies{
		Config:              cfg,
		AuthService:         authService,
		ProfileService:      profileService,
		HazardService:       hazardService,
		EntranceService:     entranceService,
		FloodService:        floodService,
		HOAService:          hoaService,
		CommunityService:    communityService,
		WeatherService:      weatherService,
		RoutingService:      routingService,
		RouteProductService: routeProductService,
		Hub:                 hub,
	}

	return handlers.SetupRouter(deps)
}

func TestHealthCheck(t *testing.T) {
	app := setupTestApp()

	req := httptest.NewRequest(http.MethodGet, "/api/health", nil)
	rr := httptest.NewRecorder()
	app.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rr.Code)
	}

	var body map[string]interface{}
	if err := json.Unmarshal(rr.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if body["status"] != "ok" || body["service"] != "smartroad-api" {
		t.Fatalf("unexpected body: %v", body)
	}
}

func TestRoutingValidation(t *testing.T) {
	app := setupTestApp()

	validRequest := map[string]interface{}{
		"start":   map[string]float64{"lat": 14.5995, "lon": 120.9842},
		"end":     map[string]float64{"lat": 14.6760, "lon": 121.0437},
		"vehicle": "car",
	}

	// 1. Missing start
	{
		payload, _ := json.Marshal(map[string]interface{}{
			"end":     validRequest["end"],
			"vehicle": "car",
		})
		req := httptest.NewRequest(http.MethodPost, "/api/routing/route", bytes.NewReader(payload))
		req.Header.Set("Content-Type", "application/json")
		rr := httptest.NewRecorder()
		app.ServeHTTP(rr, req)

		if rr.Code != http.StatusBadRequest {
			t.Errorf("expected status 400 for missing start, got %d", rr.Code)
		}
	}

	// 2. Missing vehicle
	{
		payload, _ := json.Marshal(map[string]interface{}{
			"start": validRequest["start"],
			"end":   validRequest["end"],
		})
		req := httptest.NewRequest(http.MethodPost, "/api/routing/route", bytes.NewReader(payload))
		req.Header.Set("Content-Type", "application/json")
		rr := httptest.NewRecorder()
		app.ServeHTTP(rr, req)

		if rr.Code != http.StatusBadRequest {
			t.Errorf("expected status 400 for missing vehicle, got %d", rr.Code)
		}
	}

	// 3. Invalid vehicle
	{
		payload, _ := json.Marshal(map[string]interface{}{
			"start":   validRequest["start"],
			"end":     validRequest["end"],
			"vehicle": "helicopter",
		})
		req := httptest.NewRequest(http.MethodPost, "/api/routing/route", bytes.NewReader(payload))
		req.Header.Set("Content-Type", "application/json")
		rr := httptest.NewRecorder()
		app.ServeHTTP(rr, req)

		if rr.Code != http.StatusBadRequest {
			t.Errorf("expected status 400 for invalid vehicle, got %d", rr.Code)
		}
	}

	// 4. Out of range coordinates
	{
		payload, _ := json.Marshal(map[string]interface{}{
			"start":   map[string]float64{"lat": 999.0, "lon": 999.0},
			"end":     validRequest["end"],
			"vehicle": "car",
		})
		req := httptest.NewRequest(http.MethodPost, "/api/routing/route", bytes.NewReader(payload))
		req.Header.Set("Content-Type", "application/json")
		rr := httptest.NewRecorder()
		app.ServeHTTP(rr, req)

		if rr.Code != http.StatusBadRequest {
			t.Errorf("expected status 400 for out-of-range coordinates, got %d", rr.Code)
		}
	}

	// 5. Valid request fallback route calculation
	{
		vehicles := []string{
			"car", "motorcycle", "big_bike", "truck", "pedestrian",
			"delivery_rider", "flood_safe", "weather_safe", "hoa_access",
		}
		for _, v := range vehicles {
			payload, _ := json.Marshal(map[string]interface{}{
				"start":   validRequest["start"],
				"end":     validRequest["end"],
				"vehicle": v,
			})
			req := httptest.NewRequest(http.MethodPost, "/api/routing/route", bytes.NewReader(payload))
			req.Header.Set("Content-Type", "application/json")
			rr := httptest.NewRecorder()
			app.ServeHTTP(rr, req)

			if rr.Code != http.StatusOK {
				t.Fatalf("expected status 200 for vehicle %s, got %d: %s", v, rr.Code, rr.Body.String())
			}

			var resp struct {
				Success bool             `json:"success"`
				Data    models.RouteData `json:"data"`
			}
			if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
				t.Fatalf("failed to decode route response: %v", err)
			}
			if !resp.Success || len(resp.Data.Points) < 2 {
				t.Fatalf("expected valid route points for vehicle %s", v)
			}
		}
	}
}

func TestRoutingVehicles(t *testing.T) {
	app := setupTestApp()

	req := httptest.NewRequest(http.MethodGet, "/api/routing/vehicles", nil)
	rr := httptest.NewRecorder()
	app.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}

	var resp struct {
		Success bool                     `json:"success"`
		Data    []models.VehicleTypeInfo `json:"data"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal: %v", err)
	}

	if !resp.Success || len(resp.Data) < 4 {
		t.Fatalf("expected at least 4 vehicle profiles, got %d", len(resp.Data))
	}
}

func TestAuthAndProtectedRoutes(t *testing.T) {
	app := setupTestApp()

	// 1. Login with demo user
	loginPayload, _ := json.Marshal(map[string]string{
		"email":    "demo@smartroad.app",
		"password": "DemoPass123!",
	})
	req := httptest.NewRequest(http.MethodPost, "/api/auth/login", bytes.NewReader(loginPayload))
	req.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()
	app.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected login 200, got %d: %s", rr.Code, rr.Body.String())
	}

	var loginResp struct {
		Success bool `json:"success"`
		Data    struct {
			Token string `json:"token"`
		} `json:"data"`
	}
	_ = json.Unmarshal(rr.Body.Bytes(), &loginResp)
	token := loginResp.Data.Token
	if token == "" {
		t.Fatalf("expected non-empty token")
	}

	// 2. Access /api/auth/me with Bearer token
	reqMe := httptest.NewRequest(http.MethodGet, "/api/auth/me", nil)
	reqMe.Header.Set("Authorization", "Bearer "+token)
	rrMe := httptest.NewRecorder()
	app.ServeHTTP(rrMe, reqMe)

	if rrMe.Code != http.StatusOK {
		t.Fatalf("expected 200 for /api/auth/me, got %d: %s", rrMe.Code, rrMe.Body.String())
	}

	// 3. Access without token should be 401
	reqUnauth := httptest.NewRequest(http.MethodGet, "/api/auth/me", nil)
	rrUnauth := httptest.NewRecorder()
	app.ServeHTTP(rrUnauth, reqUnauth)

	if rrUnauth.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for unauthenticated request, got %d", rrUnauth.Code)
	}
}
