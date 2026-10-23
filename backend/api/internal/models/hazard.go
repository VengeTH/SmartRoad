package models

import "time"

type Hazard struct {
	ID          string    `json:"id"`
	UserID      string    `json:"userId"`
	Type        string    `json:"type"`
	Description string    `json:"description"`
	Severity    string    `json:"severity"`
	Latitude    float64   `json:"latitude"`
	Longitude   float64   `json:"longitude"`
	ImageURL    *string   `json:"imageUrl,omitempty"`
	CreatedAt   time.Time `json:"createdAt"`
	UpdatedAt   time.Time `json:"updatedAt"`
}

type CreateHazardRequest struct {
	Type        string  `json:"type"`
	Description string  `json:"description"`
	Severity    string  `json:"severity"`
	Latitude    float64 `json:"latitude"`
	Longitude   float64 `json:"longitude"`
	ImageURL    *string `json:"imageUrl,omitempty"`
}

type UpdateHazardRequest struct {
	Type        string  `json:"type,omitempty"`
	Description string  `json:"description,omitempty"`
	Severity    string  `json:"severity,omitempty"`
	ImageURL    *string `json:"imageUrl,omitempty"`
}

type HazardFilter struct {
	Limit    int
	Offset   int
	Type     string
	Severity string
	UserID   string
}
