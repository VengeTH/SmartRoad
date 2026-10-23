package services

import (
	"fmt"
	"math"

	"smartroad-api/internal/models"
	"smartroad-api/internal/utils"
)

type RouteSafetyResult struct {
	Safe           bool                   `json:"safe"`
	Score          float64                `json:"score"`
	Warnings       []models.RouteWarning  `json:"warnings"`
	DangerSegments []models.DangerSegment `json:"dangerSegments"`
}

func AssessRouteSafety(routePoints []models.LatLngPoint, floodZones []*models.FloodZone, hazards []*models.Hazard) RouteSafetyResult {
	if len(routePoints) < 2 {
		return RouteSafetyResult{Safe: true, Score: 1.0, Warnings: []models.RouteWarning{}, DangerSegments: []models.DangerSegment{}}
	}

	var dangerSegments []models.DangerSegment
	totalDangerScore := 0.0
	totalSegments := len(routePoints) - 1

	for i := 0; i < len(routePoints)-1; i++ {
		p1 := routePoints[i]
		p2 := routePoints[i+1]
		midLat := (p1.Lat + p2.Lat) / 2.0
		midLng := (p1.Lng + p2.Lng) / 2.0
		segmentDanger := 0.0

		// Check flood zones
		for _, fz := range floodZones {
			dist := utils.HaversineKm(midLat, midLng, fz.Latitude, fz.Longitude)
			if dist < fz.RadiusKm {
				sevVal := 0.2
				switch fz.Severity {
				case "extreme":
					sevVal = 0.8
				case "high":
					sevVal = 0.6
				case "moderate":
					sevVal = 0.4
				}
				if sevVal > segmentDanger {
					segmentDanger = sevVal
				}

				found := false
				for _, d := range dangerSegments {
					if d.Index == i {
						found = true
						break
					}
				}
				if !found {
					dangerSegments = append(dangerSegments, models.DangerSegment{
						Index:    i,
						Type:     "flood",
						Severity: fz.Severity,
						Name:     fz.Name,
					})
				}
			}
		}

		// Check hazards
		for _, h := range hazards {
			dist := utils.HaversineKm(midLat, midLng, h.Latitude, h.Longitude)
			if dist < 0.5 { // within 500m
				sevVal := 0.2
				switch h.Severity {
				case "High":
					sevVal = 0.7
				case "Medium":
					sevVal = 0.4
				}
				if sevVal > segmentDanger {
					segmentDanger = sevVal
				}

				found := false
				for _, d := range dangerSegments {
					if d.Index == i {
						found = true
						break
					}
				}
				if !found {
					dangerSegments = append(dangerSegments, models.DangerSegment{
						Index:    i,
						Type:     h.Type,
						Severity: h.Severity,
						ID:       h.ID,
					})
				}
			}
		}

		totalDangerScore += segmentDanger
	}

	avgDanger := 0.0
	if totalSegments > 0 {
		avgDanger = totalDangerScore / float64(totalSegments)
	}

	safetyScore := math.Max(0.0, math.Min(1.0, 1.0-avgDanger))
	safetyScore = math.Round(safetyScore*100) / 100

	var warnings []models.RouteWarning
	if len(dangerSegments) > 0 {
		areaWord := "areas"
		if len(dangerSegments) == 1 {
			areaWord = "area"
		}
		warnings = append(warnings, models.RouteWarning{
			Type:        "route_danger",
			Message:     fmt.Sprintf("Route passes through %d dangerous %s", len(dangerSegments), areaWord),
			Segments:    dangerSegments,
			SafetyScore: safetyScore,
		})
	}

	return RouteSafetyResult{
		Safe:           len(dangerSegments) == 0,
		Score:          safetyScore,
		Warnings:       warnings,
		DangerSegments: dangerSegments,
	}
}
