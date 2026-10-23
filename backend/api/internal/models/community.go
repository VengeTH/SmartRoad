package models

import "time"

type Comment struct {
	ID         string    `json:"id"`
	ParentType string    `json:"parentType"`
	ParentID   string    `json:"parentId"`
	UserID     string    `json:"userId"`
	UserName   string    `json:"userName"`
	Text       string    `json:"text"`
	CreatedAt  time.Time `json:"createdAt"`
	UpdatedAt  time.Time `json:"updatedAt"`
}

type CreateCommentRequest struct {
	ParentType string `json:"parentType"`
	ParentID   string `json:"parentId"`
	Text       string `json:"text"`
}

type UpdateCommentRequest struct {
	Text string `json:"text"`
}

type ToggleLikeRequest struct {
	ParentType string `json:"parentType"`
	ParentID   string `json:"parentId"`
}

type SetRatingRequest struct {
	ParentType string  `json:"parentType"`
	ParentID   string  `json:"parentId"`
	Rating     float64 `json:"rating"`
}

type RatingSummary struct {
	AvgRating    float64 `json:"avgRating"`
	RatingsCount int     `json:"ratingsCount"`
}
