package services

import (
	"errors"
	"sort"
	"sync"
	"time"

	"smartroad-api/internal/models"
	"smartroad-api/internal/utils"

	"github.com/google/uuid"
)

var (
	ErrRouteNotFound = errors.New("ROUTE_NOT_FOUND")
)

type RouteProductService struct {
	savedRoutes map[string]*models.SavedRoute
	shares      map[string]string // token -> routeID
	purchases   map[string]bool   // userID:routeID -> bool
	mu          sync.RWMutex
}

func NewRouteProductService() *RouteProductService {
	s := &RouteProductService{
		savedRoutes: make(map[string]*models.SavedRoute),
		shares:      make(map[string]string),
		purchases:   make(map[string]bool),
	}
	s.seedDemoRoutes()
	return s
}

func (s *RouteProductService) seedDemoRoutes() {
	id := uuid.New().String()
	s.savedRoutes[id] = &models.SavedRoute{
		ID:          id,
		UserID:      "demo-user-id",
		Name:        "Makati to BGC via Kalayaan",
		Description: "Fast motorbike shortcut avoiding main avenue traffic",
		Geometry: models.GeoJSONGeometry{
			Type: "LineString",
			Coordinates: [][]float64{
				{121.0244, 14.5547},
				{121.0350, 14.5510},
				{121.0503, 14.5492},
			},
		},
		StartPoint:               models.LatLngPoint{Lat: 14.5547, Lng: 121.0244},
		EndPoint:                 models.LatLngPoint{Lat: 14.5492, Lng: 121.0503},
		DistanceMeters:           4500,
		EstimatedDurationSeconds: 720,
		VehicleType:              "motorcycle",
		CountryCode:              "PH",
		City:                     "Makati",
		Tags:                     map[string]bool{"toll_free": true, "rain_safe": true},
		PriceCents:               0,
		IsPublic:                 true,
		TrustScore:               94.5,
		UsageCount:               312,
		RatingAvg:                4.8,
		CreatedAt:                time.Now().Add(-24 * time.Hour),
		UpdatedAt:                time.Now().Add(-24 * time.Hour),
	}
}

func (s *RouteProductService) SaveRoute(userID string, req models.SaveRouteRequest) (*models.SavedRoute, error) {
	if req.Name == "" || len(req.Geometry.Coordinates) < 2 {
		return nil, ErrValidationFailed
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	id := uuid.New().String()
	coords := req.Geometry.Coordinates

	startPoint := models.LatLngPoint{Lat: coords[0][1], Lng: coords[0][0]}
	if req.StartPoint != nil {
		startPoint = *req.StartPoint
	}

	endPoint := models.LatLngPoint{Lat: coords[len(coords)-1][1], Lng: coords[len(coords)-1][0]}
	if req.EndPoint != nil {
		endPoint = *req.EndPoint
	}

	vehicle := req.VehicleType
	if vehicle == "" {
		vehicle = "motorcycle"
	}

	route := &models.SavedRoute{
		ID:                       id,
		UserID:                   userID,
		Name:                     req.Name,
		Description:              req.Description,
		Geometry:                 req.Geometry,
		StartPoint:               startPoint,
		EndPoint:                 endPoint,
		DistanceMeters:           req.DistanceMeters,
		EstimatedDurationSeconds: req.EstimatedDurationSeconds,
		VehicleType:              vehicle,
		CountryCode:              req.CountryCode,
		City:                     req.City,
		Tags:                     req.Tags,
		PriceCents:               req.PriceCents,
		IsPublic:                 req.IsPublic,
		WeatherAtSave:            req.WeatherAtSave,
		TrustScore:               50.0,
		UsageCount:               1,
		RatingAvg:                0.0,
		CreatedAt:                time.Now(),
		UpdatedAt:                time.Now(),
	}

	s.savedRoutes[id] = route
	return route, nil
}

func (s *RouteProductService) DiscoverRoutes(filter models.DiscoverRoutesFilter) []*models.SavedRoute {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var results []*models.SavedRoute
	radiusMeters := filter.RadiusMeters
	if radiusMeters <= 0 {
		radiusMeters = 5000.0
	}

	for _, r := range s.savedRoutes {
		if !r.IsPublic {
			continue
		}
		if filter.VehicleType != "" && r.VehicleType != filter.VehicleType {
			continue
		}

		distKm := utils.HaversineKm(filter.Lat, filter.Lng, r.StartPoint.Lat, r.StartPoint.Lng)
		distMeters := distKm * 1000.0

		if distMeters <= radiusMeters {
			cpy := *r
			cpy.DistanceToRouteMeters = &distMeters
			results = append(results, &cpy)
		}
	}

	sort.Slice(results, func(i, j int) bool {
		return results[i].TrustScore > results[j].TrustScore
	})

	limit := filter.Limit
	if limit > 0 && len(results) > limit {
		results = results[:limit]
	}

	return results
}

func (s *RouteProductService) GetRouteByID(id string) (*models.SavedRoute, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	r, exists := s.savedRoutes[id]
	if !exists {
		return nil, ErrRouteNotFound
	}
	return r, nil
}
