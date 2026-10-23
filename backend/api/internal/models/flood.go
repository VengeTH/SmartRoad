package models

import "time"

type FloodZone struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	Severity  string    `json:"severity"`
	Latitude  float64   `json:"latitude"`
	Longitude float64   `json:"longitude"`
	RadiusKm  float64   `json:"radiusKm"`
	IsActive  bool      `json:"isActive"`
	CreatedAt time.Time `json:"createdAt"`
}

type CreateFloodZoneRequest struct {
	Name     string  `json:"name"`
	Severity string  `json:"severity"`
	Lat      float64 `json:"lat"`
	Lng      float64 `json:"lng"`
	RadiusKm float64 `json:"radiusKm"`
}
