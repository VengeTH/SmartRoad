package models

type Coord struct {
	Lat float64 `json:"lat"`
	Lon float64 `json:"lon"`
}

type LatLngPoint struct {
	Lat float64 `json:"lat"`
	Lng float64 `json:"lng"`
}

type RouteRequest struct {
	Start            Coord    `json:"start"`
	End              Coord    `json:"end"`
	Vehicle          string   `json:"vehicle"`
	Waypoints        []Coord  `json:"waypoints,omitempty"`
	AvoidTolls       *bool    `json:"avoid_tolls,omitempty"`
	UserStickerIDs   []string `json:"user_sticker_ids,omitempty"`
	RestrictedHoaIDs []string `json:"restricted_hoa_ids,omitempty"`
}

type DangerSegment struct {
	Index    int    `json:"index"`
	Type     string `json:"type"`
	Severity string `json:"severity"`
	Name     string `json:"name,omitempty"`
	ID       string `json:"id,omitempty"`
}

type RouteWarning struct {
	Type        string          `json:"type"`
	Message     string          `json:"message"`
	Segments    []DangerSegment `json:"segments"`
	SafetyScore float64         `json:"safetyScore"`
}

type RouteMetadata struct {
	TimeMs            int64    `json:"time_ms"`
	DistanceMeters    float64  `json:"distance_meters"`
	InstructionsCount int      `json:"instructions_count"`
	PointsCount       int      `json:"points_count"`
	Ascend            *float64 `json:"ascend,omitempty"`
	Descend           *float64 `json:"descend,omitempty"`
	IsFallback        bool     `json:"is_fallback,omitempty"`
}

type RouteData struct {
	Points             []LatLngPoint  `json:"points"`
	DistanceKm         float64        `json:"distance_km"`
	DistanceMeters     int64          `json:"distance_meters"`
	DurationSeconds    int64          `json:"duration_seconds"`
	DurationMinutes    int64          `json:"duration_minutes"`
	DurationFormatted  string         `json:"duration_formatted"`
	Instructions       string         `json:"instructions,omitempty"`
	Vehicle            string         `json:"vehicle"`
	IsFallback         bool           `json:"is_fallback,omitempty"`
	HOAWarning         bool           `json:"hoa_warning,omitempty"`
	HOAMissingStickers []string       `json:"hoa_missing_stickers,omitempty"`
	Metadata           RouteMetadata  `json:"metadata"`
	SafetyScore        float64        `json:"safety_score,omitempty"`
	Warnings           []RouteWarning `json:"warnings,omitempty"`
}

type VehicleTypeInfo struct {
	ID    string `json:"id"`
	Label string `json:"label"`
}
