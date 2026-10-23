package utils

import (
	"math"
)

const EarthRadiusKm = 6371.0

// HaversineKm calculates the great circle distance between two points on Earth in kilometers.
func HaversineKm(lat1, lon1, lat2, lon2 float64) float64 {
	dLat := toRad(lat2 - lat1)
	dLon := toRad(lon2 - lon1)
	lat1Rad := toRad(lat1)
	lat2Rad := toRad(lat2)

	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1Rad)*math.Cos(lat2Rad)*math.Sin(dLon/2)*math.Sin(dLon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return EarthRadiusKm * c
}

func toRad(deg float64) float64 {
	return deg * math.Pi / 180.0
}

// Point represents a latitude/longitude coordinate.
type Point struct {
	Lat float64 `json:"lat"`
	Lng float64 `json:"lng"`
}

// DecodePolyline decodes Google Encoded Polyline into a slice of Points.
func DecodePolyline(encoded string) []Point {
	if len(encoded) == 0 {
		return []Point{}
	}

	points := make([]Point, 0)
	index := 0
	lat := 0
	lng := 0

	for index < len(encoded) {
		var b int
		shift := 0
		result := 0

		for {
			if index >= len(encoded) {
				return points
			}
			b = int(encoded[index]) - 63
			index++
			result |= (b & 0x1f) << shift
			shift += 5
			if b < 0x20 {
				break
			}
		}

		dlat := 0
		if (result & 1) != 0 {
			dlat = ^(result >> 1)
		} else {
			dlat = result >> 1
		}
		lat += dlat

		shift = 0
		result = 0
		for {
			if index >= len(encoded) {
				return points
			}
			b = int(encoded[index]) - 63
			index++
			result |= (b & 0x1f) << shift
			shift += 5
			if b < 0x20 {
				break
			}
		}

		dlng := 0
		if (result & 1) != 0 {
			dlng = ^(result >> 1)
		} else {
			dlng = result >> 1
		}
		lng += dlng

		points = append(points, Point{
			Lat: float64(lat) / 1e5,
			Lng: float64(lng) / 1e5,
		})
	}

	return points
}
