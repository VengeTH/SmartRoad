package models

import "time"

type GeoJSONGeometry struct {
	Type        string      `json:"type"`
	Coordinates [][]float64 `json:"coordinates"`
}

type RouteWeatherSnapshot struct {
	Rain       bool   `json:"rain"`
	FloodRisk  string `json:"flood_risk"`
	Visibility string `json:"visibility"`
}

type SavedRoute struct {
	ID                       string                `json:"id"`
	UserID                   string                `json:"user_id"`
	Name                     string                `json:"name"`
	Description              string                `json:"description"`
	Geometry                 GeoJSONGeometry       `json:"geometry"`
	StartPoint               LatLngPoint           `json:"start_point"`
	EndPoint                 LatLngPoint           `json:"end_point"`
	DistanceMeters           int64                 `json:"distance_meters"`
	EstimatedDurationSeconds int64                 `json:"estimated_duration_seconds"`
	VehicleType              string                `json:"vehicle_type"`
	CountryCode              string                `json:"country_code"`
	City                     string                `json:"city"`
	Tags                     map[string]bool       `json:"tags"`
	PriceCents               int                   `json:"price_cents"`
	IsPublic                 bool                  `json:"is_public"`
	WeatherAtSave            *RouteWeatherSnapshot `json:"weather_at_save,omitempty"`
	TrustScore               float64               `json:"trust_score"`
	UsageCount               int                   `json:"usage_count"`
	RatingAvg                float64               `json:"rating_avg"`
	DistanceToRouteMeters    *float64              `json:"distance_to_route_meters,omitempty"`
	IsPurchased              bool                  `json:"is_purchased"`
	CreatedAt                time.Time             `json:"created_at"`
	UpdatedAt                time.Time             `json:"updated_at"`
}

type SaveRouteRequest struct {
	Name                     string                `json:"name"`
	Description              string                `json:"description"`
	Geometry                 GeoJSONGeometry       `json:"geometry"`
	StartPoint               *LatLngPoint          `json:"start_point,omitempty"`
	EndPoint                 *LatLngPoint          `json:"end_point,omitempty"`
	DistanceMeters           int64                 `json:"distance_meters"`
	EstimatedDurationSeconds int64                 `json:"estimated_duration_seconds"`
	VehicleType              string                `json:"vehicle_type"`
	CountryCode              string                `json:"country_code"`
	City                     string                `json:"city"`
	Tags                     map[string]bool       `json:"tags"`
	PriceCents               int                   `json:"price_cents"`
	IsPublic                 bool                  `json:"is_public"`
	WeatherAtSave            *RouteWeatherSnapshot `json:"weather_at_save,omitempty"`
}

type DiscoverRoutesFilter struct {
	Lat          float64
	Lng          float64
	RadiusMeters float64
	VehicleType  string
	Tags         []string
	Limit        int
	Sort         string
}
