package services

import (
	"errors"
	"sort"
	"sync"
	"time"

	"smartroad-api/internal/models"
	"smartroad-api/internal/utils"

	"github.com/google/uuid"
)

var (
	ErrHazardNotFound = errors.New("HAZARD_NOT_FOUND")
	ErrUnauthorized   = errors.New("UNAUTHORIZED")
)

type HazardService struct {
	hazards map[string]*models.Hazard
	mu      sync.RWMutex
}

func NewHazardService() *HazardService {
	s := &HazardService{
		hazards: make(map[string]*models.Hazard),
	}
	s.seedDemoHazards()
	return s
}

func (s *HazardService) seedDemoHazards() {
	demos := []struct {
		typ, desc, sev string
		lat, lng       float64
	}{
		{"pothole", "Large pothole on Taft Ave", "Medium", 14.5995, 120.9842},
		{"flood", "Flooding in Makati", "High", 14.5500, 121.0000},
		{"accident", "Multi-vehicle collision", "High", 14.6200, 121.0100},
	}

	for _, d := range demos {
		id := uuid.New().String()
		s.hazards[id] = &models.Hazard{
			ID:          id,
			UserID:      "demo-user-id",
			Type:        d.typ,
			Description: d.desc,
			Severity:    d.sev,
			Latitude:    d.lat,
			Longitude:   d.lng,
			CreatedAt:   time.Now(),
			UpdatedAt:   time.Now(),
		}
	}
}

func (s *HazardService) CreateHazard(userID string, req models.CreateHazardRequest) (*models.Hazard, error) {
	if req.Type == "" || req.Description == "" || req.Severity == "" || req.Latitude == 0 || req.Longitude == 0 {
		return nil, ErrValidationFailed
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	id := uuid.New().String()
	hazard := &models.Hazard{
		ID:          id,
		UserID:      userID,
		Type:        req.Type,
		Description: req.Description,
		Severity:    req.Severity,
		Latitude:    req.Latitude,
		Longitude:   req.Longitude,
		ImageURL:    req.ImageURL,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	s.hazards[id] = hazard
	return hazard, nil
}

func (s *HazardService) GetHazards(filter models.HazardFilter) ([]*models.Hazard, int) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var list []*models.Hazard
	for _, h := range s.hazards {
		if filter.Type != "" && h.Type != filter.Type {
			continue
		}
		if filter.Severity != "" && h.Severity != filter.Severity {
			continue
		}
		if filter.UserID != "" && h.UserID != filter.UserID {
			continue
		}
		list = append(list, h)
	}

	// Sort descending by created time
	sort.Slice(list, func(i, j int) bool {
		return list[i].CreatedAt.After(list[j].CreatedAt)
	})

	total := len(list)
	if filter.Offset > total {
		return []*models.Hazard{}, total
	}

	end := filter.Offset + filter.Limit
	if filter.Limit <= 0 {
		end = total
	} else if end > total {
		end = total
	}

	return list[filter.Offset:end], total
}

func (s *HazardService) GetNearbyHazards(lat, lng, radiusKm float64) []*models.Hazard {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var list []*models.Hazard
	for _, h := range s.hazards {
		dist := utils.HaversineKm(lat, lng, h.Latitude, h.Longitude)
		if dist <= radiusKm {
			list = append(list, h)
		}
	}

	sort.Slice(list, func(i, j int) bool {
		return list[i].CreatedAt.After(list[j].CreatedAt)
	})

	return list
}

func (s *HazardService) GetHazardsInBounds(minLat, maxLat, minLng, maxLng float64) []*models.Hazard {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var list []*models.Hazard
	for _, h := range s.hazards {
		if h.Latitude >= minLat && h.Latitude <= maxLat &&
			h.Longitude >= minLng && h.Longitude <= maxLng {
			list = append(list, h)
		}
	}

	sort.Slice(list, func(i, j int) bool {
		return list[i].CreatedAt.After(list[j].CreatedAt)
	})

	return list
}

func (s *HazardService) GetHazardByID(id string) (*models.Hazard, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	h, exists := s.hazards[id]
	if !exists {
		return nil, ErrHazardNotFound
	}
	return h, nil
}

func (s *HazardService) UpdateHazard(id, userID string, req models.UpdateHazardRequest) (*models.Hazard, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	h, exists := s.hazards[id]
	if !exists {
		return nil, ErrHazardNotFound
	}

	if h.UserID != userID && userID != "admin" {
		return nil, ErrUnauthorized
	}

	if req.Type != "" {
		h.Type = req.Type
	}
	if req.Description != "" {
		h.Description = req.Description
	}
	if req.Severity != "" {
		h.Severity = req.Severity
	}
	if req.ImageURL != nil {
		h.ImageURL = req.ImageURL
	}
	h.UpdatedAt = time.Now()

	return h, nil
}

func (s *HazardService) DeleteHazard(id, userID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	h, exists := s.hazards[id]
	if !exists {
		return nil
	}

	if h.UserID != userID && userID != "admin" {
		return ErrUnauthorized
	}

	delete(s.hazards, id)
	return nil
}

func (s *HazardService) GetAllList() []*models.Hazard {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var list []*models.Hazard
	for _, h := range s.hazards {
		list = append(list, h)
	}
	return list
}
