package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"smartroad-api/internal/config"
	"smartroad-api/internal/handlers"
	"smartroad-api/internal/services"
	"smartroad-api/internal/websocket"
)

func main() {
	cfg := config.Load()

	log.Printf("Starting SmartRoad Go Backend on port %s [%s]", cfg.Port, cfg.Env)
	log.Printf("GraphHopper URL: %s (timeout: %s, max retries: %d)", cfg.GraphHopperURL, cfg.GraphHopperTimeout, cfg.GraphHopperMaxRetries)

	// Initialize Services
	authService := services.NewAuthService(cfg)
	profileService := services.NewProfileService()
	hazardService := services.NewHazardService()
	entranceService := services.NewEntranceService()
	floodService := services.NewFloodService()
	hoaService := services.NewHOAService()
	communityService := services.NewCommunityService()
	weatherService := services.NewWeatherService()
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

	router := handlers.SetupRouter(deps)

	server := &http.Server{
		Addr:         fmt.Sprintf(":%s", cfg.Port),
		Handler:      router,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// Server run context
	serverCtx, serverStopCtx := context.WithCancel(context.Background())

	// Listen for syscall signals for process to interrupt/quit
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGHUP, syscall.SIGINT, syscall.SIGTERM, syscall.SIGQUIT)

	go func() {
		<-sig

		// Shutdown signal with grace period of 30 seconds
		shutdownCtx, shutdownCancel := context.WithTimeout(serverCtx, 30*time.Second)
		defer shutdownCancel()

		go func() {
			<-shutdownCtx.Done()
			if shutdownCtx.Err() == context.DeadlineExceeded {
				log.Fatal("Graceful shutdown timed out.. forcing exit.")
			}
		}()

		log.Println("Shutting down server gracefully...")
		if err := server.Shutdown(shutdownCtx); err != nil {
			log.Fatalf("Server shutdown error: %v", err)
		}
		serverStopCtx()
	}()

	log.Printf("SmartRoad API listening on http://0.0.0.0:%s", cfg.Port)
	log.Printf("WebSocket available at ws://0.0.0.0:%s/ws", cfg.Port)

	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Server failed to start: %v", err)
	}

	<-serverCtx.Done()
	log.Println("Server stopped")
}
