package services

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"net/url"
	"strings"
	"time"

	"smartroad-api/internal/config"
	"smartroad-api/internal/models"
	"smartroad-api/internal/utils"
)

var (
	ErrNoRouteFound    = errors.New("NO_ROUTE")
	ErrInvalidGeometry = errors.New("INVALID_ROUTE_GEOMETRY")
	ErrGraphHopperDown = errors.New("UPSTREAM_UNAVAILABLE")
)

type RoutingService struct {
	cfg           *config.Config
	client        *http.Client
	hazardService *HazardService
	floodService  *FloodService
}

func NewRoutingService(cfg *config.Config, hazardService *HazardService, floodService *FloodService) *RoutingService {
	transport := &http.Transport{
		MaxIdleConns:        100,
		MaxIdleConnsPerHost: 20,
		IdleConnTimeout:     90 * time.Second,
	}

	return &RoutingService{
		cfg: cfg,
		client: &http.Client{
			Transport: transport,
		},
		hazardService: hazardService,
		floodService:  floodService,
	}
}

// GraphHopper Response schema
type ghResponse struct {
	Paths []struct {
		Distance float64  `json:"distance"`
		Time     int64    `json:"time"`
		Ascend   *float64 `json:"ascend"`
		Descend  *float64 `json:"descend"`
		Points   struct {
			Coordinates [][]float64 `json:"coordinates"`
		} `json:"points"`
		Instructions []struct {
			Text string `json:"text"`
		} `json:"instructions"`
	} `json:"paths"`
}

var ValidVehicles = []string{
	"car",
	"motorcycle",
	"big_bike",
	"truck",
	"pedestrian",
	"delivery_rider",
	"flood_safe",
	"weather_safe",
	"hoa_access",
}

func (s *RoutingService) CalculateRoute(req models.RouteRequest) (*models.RouteData, bool, error) {
	ghVehicle := mapToGraphHopperProfile(req.Vehicle)

	// Build points parameter list
	pointParams := []string{
		fmt.Sprintf("%f,%f", req.Start.Lat, req.Start.Lon),
	}
	for _, wp := range req.Waypoints {
		pointParams = append(pointParams, fmt.Sprintf("%f,%f", wp.Lat, wp.Lon))
	}
	pointParams = append(pointParams, fmt.Sprintf("%f,%f", req.End.Lat, req.End.Lon))

	avoidTolls := true
	if req.AvoidTolls != nil {
		avoidTolls = *req.AvoidTolls
	}

	ghResp, err := s.callGraphHopper(pointParams, ghVehicle, avoidTolls, 0)
	if err != nil {
		log.Printf("GraphHopper unavailable (%v) - calculating fallback route", err)
		fallback := s.calculateFallback(req.Start, req.End, req.Vehicle, req.Waypoints)
		return fallback, true, nil
	}

	route, err := s.parseGraphHopperResponse(ghResp, req.Vehicle)
	if err != nil {
		log.Printf("Error parsing GraphHopper response (%v) - calculating fallback", err)
		fallback := s.calculateFallback(req.Start, req.End, req.Vehicle, req.Waypoints)
		return fallback, true, nil
	}

	// HOA restriction check
	if len(req.RestrictedHoaIDs) > 0 {
		var missing []string
		for _, rid := range req.RestrictedHoaIDs {
			has := false
			for _, uid := range req.UserStickerIDs {
				if uid == rid {
					has = true
					break
				}
			}
			if !has {
				missing = append(missing, rid)
			}
		}
		if len(missing) > 0 {
			route.HOAWarning = true
			route.HOAMissingStickers = missing
		}
	}

	// SmartRoad safety assessment
	if s.floodService != nil && s.hazardService != nil {
		assessment := AssessRouteSafety(route.Points, s.floodService.GetAllList(), s.hazardService.GetAllList())
		route.SafetyScore = assessment.Score
		route.Warnings = assessment.Warnings
	}

	return route, false, nil
}

func (s *RoutingService) callGraphHopper(points []string, vehicle string, avoidTolls bool, retryCount int) (*ghResponse, error) {
	u, err := url.Parse(fmt.Sprintf("%s/route", s.cfg.GraphHopperURL))
	if err != nil {
		return nil, err
	}

	q := u.Query()
	for _, pt := range points {
		q.Add("point", pt)
	}
	q.Set("vehicle", vehicle)
	q.Set("type", "json")
	q.Set("instructions", "true")
	q.Set("calc_points", "true")
	q.Set("points_encoded", "false")
	if avoidTolls {
		q.Set("avoid", "toll")
	}
	u.RawQuery = q.Encode()

	ctx, cancel := context.WithTimeout(context.Background(), s.cfg.GraphHopperTimeout)
	defer cancel()

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("User-Agent", "SmartRoad-API/1.0-Go")

	resp, err := s.client.Do(httpReq)
	if err != nil {
		if retryCount < s.cfg.GraphHopperMaxRetries {
			time.Sleep(100 * time.Millisecond)
			return s.callGraphHopper(points, vehicle, avoidTolls, retryCount+1)
		}
		return nil, ErrGraphHopperDown
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		if retryCount < s.cfg.GraphHopperMaxRetries && resp.StatusCode >= 500 {
			time.Sleep(100 * time.Millisecond)
			return s.callGraphHopper(points, vehicle, avoidTolls, retryCount+1)
		}
		return nil, fmt.Errorf("graphhopper returned status %d: %s", resp.StatusCode, string(body))
	}

	var gh ghResponse
	if err := json.NewDecoder(resp.Body).Decode(&gh); err != nil {
		return nil, err
	}

	return &gh, nil
}

func (s *RoutingService) parseGraphHopperResponse(data *ghResponse, requestedVehicle string) (*models.RouteData, error) {
	if len(data.Paths) == 0 {
		return nil, ErrNoRouteFound
	}

	path := data.Paths[0]
	coords := path.Points.Coordinates
	if len(coords) < 2 {
		return nil, ErrInvalidGeometry
	}

	points := make([]models.LatLngPoint, len(coords))
	for i, c := range coords {
		points[i] = models.LatLngPoint{
			Lat: c[1],
			Lng: c[0],
		}
	}

	distanceMeters := path.Distance
	timeMs := path.Time
	durationSeconds := int64(math.Round(float64(timeMs) / 1000.0))

	var instrTexts []string
	for _, inst := range path.Instructions {
		if inst.Text != "" {
			instrTexts = append(instrTexts, inst.Text)
		}
	}

	distanceKm := math.Round((distanceMeters/1000.0)*100) / 100

	return &models.RouteData{
		Points:            points,
		DistanceKm:        distanceKm,
		DistanceMeters:    int64(math.Round(distanceMeters)),
		DurationSeconds:   durationSeconds,
		DurationMinutes:   int64(math.Round(float64(durationSeconds) / 60.0)),
		DurationFormatted: formatDuration(durationSeconds),
		Instructions:      strings.Join(instrTexts, " → "),
		Vehicle:           requestedVehicle,
		Metadata: models.RouteMetadata{
			TimeMs:            timeMs,
			DistanceMeters:    distanceMeters,
			InstructionsCount: len(path.Instructions),
			PointsCount:       len(points),
			Ascend:            path.Ascend,
			Descend:           path.Descend,
		},
	}, nil
}

func (s *RoutingService) calculateFallback(start, end models.Coord, vehicle string, waypoints []models.Coord) *models.RouteData {
	allPoints := []models.Coord{start}
	allPoints = append(allPoints, waypoints...)
	allPoints = append(allPoints, end)

	var interpolated []models.LatLngPoint

	for i := 0; i < len(allPoints)-1; i++ {
		from := allPoints[i]
		to := allPoints[i+1]
		dist := utils.HaversineKm(from.Lat, from.Lon, to.Lat, to.Lon)
		steps := int(math.Max(8, math.Ceil(dist*8)))

		for step := 0; step <= steps; step++ {
			t := float64(step) / float64(steps)
			interpolated = append(interpolated, models.LatLngPoint{
				Lat: from.Lat + (to.Lat-from.Lat)*t,
				Lng: from.Lon + (to.Lon-from.Lon)*t,
			})
		}
	}

	totalDistKm := 0.0
	for i := 1; i < len(interpolated); i++ {
		totalDistKm += utils.HaversineKm(
			interpolated[i-1].Lat, interpolated[i-1].Lng,
			interpolated[i].Lat, interpolated[i].Lng,
		)
	}

	avgSpeed := 40.0
	switch vehicle {
	case "car":
		avgSpeed = 45.0
	case "motorcycle", "delivery_rider", "flood_safe", "weather_safe":
		avgSpeed = 40.0
	case "big_bike":
		avgSpeed = 50.0
	case "truck", "hoa_access":
		avgSpeed = 35.0
	case "pedestrian":
		avgSpeed = 5.0
	}

	durationHours := totalDistKm / avgSpeed
	durationSeconds := int64(math.Round(durationHours * 3600))

	return &models.RouteData{
		Points:            interpolated,
		DistanceKm:        math.Round(totalDistKm*100) / 100,
		DistanceMeters:    int64(math.Round(totalDistKm * 1000)),
		DurationSeconds:   durationSeconds,
		DurationMinutes:   int64(math.Round(float64(durationSeconds) / 60.0)),
		DurationFormatted: formatDuration(durationSeconds),
		Instructions:      "Direct route (offline fallback)",
		Vehicle:           vehicle,
		IsFallback:        true,
		Metadata: models.RouteMetadata{
			TimeMs:            durationSeconds * 1000,
			DistanceMeters:    totalDistKm * 1000,
			InstructionsCount: 1,
			PointsCount:       len(interpolated),
			IsFallback:        true,
		},
	}
}

func mapToGraphHopperProfile(vehicle string) string {
	switch vehicle {
	case "car":
		return "car"
	case "motorcycle", "big_bike", "delivery_rider":
		return "motorcycle"
	case "truck":
		return "truck"
	case "pedestrian":
		return "foot"
	default:
		return "car"
	}
}

func formatDuration(totalSeconds int64) string {
	hours := totalSeconds / 3600
	minutes := (totalSeconds % 3600) / 60
	seconds := totalSeconds % 60

	var parts []string
	if hours > 0 {
		parts = append(parts, fmt.Sprintf("%dh", hours))
	}
	if minutes > 0 {
		parts = append(parts, fmt.Sprintf("%dm", minutes))
	}
	if seconds > 0 || len(parts) == 0 {
		parts = append(parts, fmt.Sprintf("%ds", seconds))
	}
	return strings.Join(parts, " ")
}
