package models

import "time"

type WeatherData struct {
	Latitude      float64   `json:"latitude"`
	Longitude     float64   `json:"longitude"`
	Temperature   float64   `json:"temperature"`
	Precipitation float64   `json:"precipitation"`
	WeatherCode   int       `json:"weatherCode"`
	WindSpeed     float64   `json:"windSpeed"`
	Humidity      float64   `json:"humidity"`
	UVIndex       float64   `json:"uvIndex"`
	Condition     string    `json:"condition"`
	Source        string    `json:"source"`
	FetchedAt     time.Time `json:"fetchedAt"`
}

type WeatherAlert struct {
	Date            string  `json:"date"`
	PrecipitationMm float64 `json:"precipitationMm"`
	ProbabilityPct  float64 `json:"probabilityPct"`
	Severity        string  `json:"severity"`
}
