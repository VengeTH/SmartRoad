package services

import (
	"errors"
	"sync"
	"time"

	"smartroad-api/internal/models"
	"smartroad-api/internal/utils"

	"github.com/google/uuid"
)

var ErrFloodZoneNotFound = errors.New("FLOOD_ZONE_NOT_FOUND")

type FloodService struct {
	zones map[string]*models.FloodZone
	mu    sync.RWMutex
}

func NewFloodService() *FloodService {
	s := &FloodService{
		zones: make(map[string]*models.FloodZone),
	}
	s.seedDemoFloodZones()
	return s
}

func (s *FloodService) seedDemoFloodZones() {
	demos := []struct {
		name, sev string
		lat, lng  float64
		radiusKm  float64
	}{
		{"Pasig River Basin", "high", 14.5600, 121.0500, 3.0},
		{"Taft Ave Flooding", "moderate", 14.5400, 120.9900, 1.5},
		{"Marikina Flood Plain", "extreme", 14.6300, 121.1000, 5.0},
	}

	for _, d := range demos {
		id := uuid.New().String()
		s.zones[id] = &models.FloodZone{
			ID:        id,
			Name:      d.name,
			Severity:  d.sev,
			Latitude:  d.lat,
			Longitude: d.lng,
			RadiusKm:  d.radiusKm,
			IsActive:  true,
			CreatedAt: time.Now(),
		}
	}
}

func (s *FloodService) GetZones(severity string) []*models.FloodZone {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var list []*models.FloodZone
	for _, z := range s.zones {
		if !z.IsActive {
			continue
		}
		if severity != "" && z.Severity != severity {
			continue
		}
		list = append(list, z)
	}
	return list
}

func (s *FloodService) CreateZone(req models.CreateFloodZoneRequest) (*models.FloodZone, error) {
	if req.Name == "" || req.Lat == 0 || req.Lng == 0 {
		return nil, ErrValidationFailed
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	id := uuid.New().String()
	sev := req.Severity
	if sev == "" {
		sev = "moderate"
	}
	rad := req.RadiusKm
	if rad <= 0 {
		rad = 1.0
	}

	z := &models.FloodZone{
		ID:        id,
		Name:      req.Name,
		Severity:  sev,
		Latitude:  req.Lat,
		Longitude: req.Lng,
		RadiusKm:  rad,
		IsActive:  true,
		CreatedAt: time.Now(),
	}

	s.zones[id] = z
	return z, nil
}

func (s *FloodService) GetNearby(lat, lng float64) []*models.FloodZone {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var list []*models.FloodZone
	for _, z := range s.zones {
		if !z.IsActive {
			continue
		}
		dist := utils.HaversineKm(lat, lng, z.Latitude, z.Longitude)
		if dist <= z.RadiusKm {
			list = append(list, z)
		}
	}
	return list
}

func (s *FloodService) GetAllList() []*models.FloodZone {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var list []*models.FloodZone
	for _, z := range s.zones {
		if z.IsActive {
			list = append(list, z)
		}
	}
	return list
}
