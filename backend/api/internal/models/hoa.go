package models

import "time"

type HOA struct {
	ID           string    `json:"id"`
	Name         string    `json:"name"`
	Description  string    `json:"description"`
	Latitude     float64   `json:"latitude"`
	Longitude    float64   `json:"longitude"`
	AccessType   string    `json:"accessType"`
	IsActive     bool      `json:"isActive"`
	RegisteredBy string    `json:"registeredBy,omitempty"`
	CreatedAt    time.Time `json:"createdAt"`
}

type RegisterHOARequest struct {
	Name        string  `json:"name"`
	Description string  `json:"description"`
	Latitude    float64 `json:"latitude"`
	Longitude   float64 `json:"longitude"`
	AccessType  string  `json:"accessType"`
}
