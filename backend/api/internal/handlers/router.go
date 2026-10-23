package handlers

import (
	"net/http"
	"time"

	"smartroad-api/internal/config"
	"smartroad-api/internal/middleware"
	"smartroad-api/internal/services"
	"smartroad-api/internal/utils"
	"smartroad-api/internal/websocket"
)

type AppDependencies struct {
	Config              *config.Config
	AuthService         *services.AuthService
	ProfileService      *services.ProfileService
	HazardService       *services.HazardService
	EntranceService     *services.EntranceService
	FloodService        *services.FloodService
	HOAService          *services.HOAService
	CommunityService    *services.CommunityService
	WeatherService      *services.WeatherService
	RoutingService      *services.RoutingService
	RouteProductService *services.RouteProductService
	Hub                 *websocket.Hub
}

func SetupRouter(deps *AppDependencies) http.Handler {
	mux := http.NewServeMux()

	authMw := middleware.NewAuthMiddleware(deps.Config.JWTSecret)
	rateLimiter := middleware.NewRateLimiter(deps.Config.RateLimitWindow, deps.Config.RateLimitMax)

	// Handlers
	routingH := NewRoutingHandler(deps.RoutingService)
	authH := NewAuthHandler(deps.AuthService)
	profileH := NewProfileHandler(deps.ProfileService)
	hazardH := NewHazardHandler(deps.HazardService, deps.Hub)
	weatherH := NewWeatherHandler(deps.WeatherService)
	communityH := NewCommunityHandler(deps.CommunityService, deps.Hub)
	entranceH := NewEntranceHandler(deps.EntranceService)
	floodH := NewFloodHandler(deps.FloodService)
	hoaH := NewHOAHandler(deps.HOAService)
	routeProductH := NewRouteProductHandler(deps.RouteProductService)

	// Health check at /api/health
	mux.HandleFunc("GET /api/health", func(w http.ResponseWriter, r *http.Request) {
		utils.JSON(w, http.StatusOK, map[string]interface{}{
			"status":    "ok",
			"service":   "smartroad-api",
			"version":   "1.0.0-go",
			"timestamp": time.Now().Format(time.RFC3339),
		})
	})

	// Routing
	mux.HandleFunc("POST /api/routing/route", routingH.HandleRoute)
	mux.HandleFunc("GET /api/routing/vehicles", routingH.HandleVehicles)
	mux.HandleFunc("GET /api/routing/health", routingH.HandleHealth)

	// Auth
	mux.HandleFunc("POST /api/auth/register", authH.HandleRegister)
	mux.HandleFunc("POST /api/auth/login", authH.HandleLogin)
	mux.Handle("GET /api/auth/me", authMw.RequireAuth(http.HandlerFunc(authH.HandleMe)))

	// Profile
	mux.Handle("GET /api/profile", authMw.RequireAuth(http.HandlerFunc(profileH.HandleProfile)))
	mux.Handle("PUT /api/profile", authMw.RequireAuth(http.HandlerFunc(profileH.HandleProfile)))

	// Hazards
	mux.Handle("GET /api/hazards", authMw.OptionalAuth(http.HandlerFunc(hazardH.HandleHazards)))
	mux.Handle("POST /api/hazards", authMw.RequireAuth(http.HandlerFunc(hazardH.HandleHazards)))
	mux.HandleFunc("GET /api/hazards/nearby", hazardH.HandleNearby)
	mux.HandleFunc("GET /api/hazards/bounds", hazardH.HandleBounds)
	mux.Handle("GET /api/hazards/{id}", authMw.OptionalAuth(http.HandlerFunc(hazardH.HandleHazardByID)))
	mux.Handle("PUT /api/hazards/{id}", authMw.RequireAuth(http.HandlerFunc(hazardH.HandleHazardByID)))
	mux.Handle("DELETE /api/hazards/{id}", authMw.RequireAuth(http.HandlerFunc(hazardH.HandleHazardByID)))

	// Weather & Proxy endpoints
	mux.HandleFunc("GET /api/weather/current", weatherH.HandleCurrent)
	mux.HandleFunc("GET /api/weather/alerts", weatherH.HandleAlerts)
	mux.HandleFunc("GET /api/weather/open-meteo/forecast", weatherH.HandleOpenMeteoForecast)
	mux.HandleFunc("GET /open-meteo/forecast", weatherH.HandleOpenMeteoForecast)
	mux.HandleFunc("GET /api/weather/rainviewer/{path...}", weatherH.HandleRainViewer)
	mux.HandleFunc("GET /rainviewer/{path...}", weatherH.HandleRainViewer)
	mux.HandleFunc("GET /api/weather/openweathermap/{path...}", weatherH.HandleOpenWeatherMap)
	mux.HandleFunc("GET /openweathermap/{path...}", weatherH.HandleOpenWeatherMap)

	// Community
	mux.Handle("GET /api/community/comments", authMw.OptionalAuth(http.HandlerFunc(communityH.HandleComments)))
	mux.Handle("POST /api/community/comments", authMw.RequireAuth(http.HandlerFunc(communityH.HandleComments)))
	mux.Handle("PUT /api/community/comments/{id}", authMw.RequireAuth(http.HandlerFunc(communityH.HandleCommentByID)))
	mux.Handle("DELETE /api/community/comments/{id}", authMw.RequireAuth(http.HandlerFunc(communityH.HandleCommentByID)))

	mux.Handle("POST /api/community/likes/toggle", authMw.RequireAuth(http.HandlerFunc(communityH.HandleLikesToggle)))
	mux.HandleFunc("GET /api/community/likes/count", communityH.HandleLikesCount)

	mux.Handle("POST /api/community/ratings", authMw.RequireAuth(http.HandlerFunc(communityH.HandleRatings)))
	mux.HandleFunc("GET /api/community/ratings/summary", communityH.HandleRatingsSummary)
	mux.Handle("GET /api/community/ratings/mine", authMw.RequireAuth(http.HandlerFunc(communityH.HandleRatingsMine)))

	// Entrances
	mux.HandleFunc("GET /api/entrances", entranceH.HandleEntrances)
	mux.Handle("POST /api/entrances", authMw.RequireAuth(http.HandlerFunc(entranceH.HandleEntrances)))
	mux.Handle("PUT /api/entrances/{id}/verify", authMw.RequireAuth(http.HandlerFunc(entranceH.HandleVerify)))
	mux.HandleFunc("GET /api/entrances/nearby", entranceH.HandleNearby)

	// Flood Zones
	mux.HandleFunc("GET /api/flood-zones", floodH.HandleFloodZones)
	mux.Handle("POST /api/flood-zones", authMw.RequireAuth(http.HandlerFunc(floodH.HandleFloodZones)))
	mux.HandleFunc("GET /api/flood-zones/nearby", floodH.HandleNearby)

	// HOAs
	mux.HandleFunc("GET /api/hoas", hoaH.HandleHOAs)
	mux.Handle("POST /api/hoas/register", authMw.RequireAuth(http.HandlerFunc(hoaH.HandleRegister)))
	mux.HandleFunc("GET /api/hoas/{id}", hoaH.HandleHOAByID)

	// Route as a Product (/api/v1/routes)
	mux.Handle("POST /api/v1/routes/save", authMw.OptionalAuth(http.HandlerFunc(routeProductH.HandleSave)))
	mux.HandleFunc("GET /api/v1/routes/discover", routeProductH.HandleDiscover)
	mux.HandleFunc("GET /api/v1/routes/{id}", routeProductH.HandleRouteByID)

	// WebSocket Pub/Sub
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		websocket.HandleWebSocket(deps.Hub, w, r)
	})

	// Wrap global middleware: CORS -> Logger -> Security -> RateLimiter -> Mux
	var handler http.Handler = mux
	handler = rateLimiter.Middleware(handler)
	handler = middleware.Security(handler)
	handler = middleware.Logger(handler)
	handler = middleware.CORS(deps.Config.CORSOrigin)(handler)

	return handler
}
