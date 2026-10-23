package models

import "time"

type Entrance struct {
	ID           string     `json:"id"`
	HoaID        string     `json:"hoaId"`
	Name         string     `json:"name"`
	EntranceType string     `json:"type"`
	Latitude     float64    `json:"lat"`
	Longitude    float64    `json:"lng"`
	IsVerified   bool       `json:"verified"`
	VerifiedBy   *string    `json:"verifiedBy,omitempty"`
	VerifiedAt   *time.Time `json:"verifiedAt,omitempty"`
	Notes        *string    `json:"notes,omitempty"`
	CreatedAt    time.Time  `json:"createdAt"`
	UpdatedAt    time.Time  `json:"updatedAt"`
}

type CreateEntranceRequest struct {
	HoaID string  `json:"hoaId"`
	Name  string  `json:"name"`
	Type  string  `json:"type"`
	Lat   float64 `json:"lat"`
	Lng   float64 `json:"lng"`
	Notes *string `json:"notes,omitempty"`
}
