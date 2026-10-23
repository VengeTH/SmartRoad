package models

import "time"

type Profile struct {
	ID                string    `json:"id"`
	Name              string    `json:"name"`
	Email             string    `json:"email"`
	PhotoURL          *string   `json:"photoUrl"`
	ReporterLevel     string    `json:"reporterLevel"`
	ValidReportsCount int       `json:"validReportsCount"`
	CreatedAt         time.Time `json:"createdAt"`
	UpdatedAt         time.Time `json:"updatedAt"`
}

type UpdateProfileRequest struct {
	Name     *string `json:"name,omitempty"`
	PhotoURL *string `json:"photoUrl,omitempty"`
}
