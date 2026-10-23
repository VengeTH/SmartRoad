package services

import (
	"errors"
	"sync"
	"time"

	"smartroad-api/internal/models"
	"smartroad-api/internal/utils"

	"github.com/google/uuid"
)

var ErrEntranceNotFound = errors.New("ENTRANCE_NOT_FOUND")

type EntranceService struct {
	entrances map[string]*models.Entrance
	mu        sync.RWMutex
}

func NewEntranceService() *EntranceService {
	s := &EntranceService{
		entrances: make(map[string]*models.Entrance),
	}
	s.seedDemoEntrances()
	return s
}

func (s *EntranceService) seedDemoEntrances() {
	demos := []struct {
		hoaID, name, typ string
		lat, lng         float64
		verified         bool
	}{
		{"hoa-bf-resort", "Main Gate", "main", 14.4244, 120.9883, true},
		{"hoa-bf-resort", "Delivery Entrance", "delivery", 14.4250, 120.9870, true},
		{"hoa-bf-resort", "Visitor Gate", "visitor", 14.4235, 120.9890, false},
		{"hoa-bf-homes", "Main Gate", "main", 14.5000, 121.0000, true},
		{"hoa-bf-homes", "Service Entrance", "service", 14.5010, 120.9990, false},
	}

	for _, d := range demos {
		id := uuid.New().String()
		s.entrances[id] = &models.Entrance{
			ID:           id,
			HoaID:        d.hoaID,
			Name:         d.name,
			EntranceType: d.typ,
			Latitude:     d.lat,
			Longitude:    d.lng,
			IsVerified:   d.verified,
			CreatedAt:    time.Now(),
			UpdatedAt:    time.Now(),
		}
	}
}

func (s *EntranceService) GetEntrances(hoaID, typ string, verified *bool) []*models.Entrance {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var list []*models.Entrance
	for _, e := range s.entrances {
		if hoaID != "" && e.HoaID != hoaID {
			continue
		}
		if typ != "" && e.EntranceType != typ {
			continue
		}
		if verified != nil && e.IsVerified != *verified {
			continue
		}
		list = append(list, e)
	}
	return list
}

func (s *EntranceService) GetEntranceByID(id string) (*models.Entrance, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	e, exists := s.entrances[id]
	if !exists {
		return nil, ErrEntranceNotFound
	}
	return e, nil
}

func (s *EntranceService) CreateEntrance(req models.CreateEntranceRequest) (*models.Entrance, error) {
	if req.HoaID == "" || req.Name == "" || req.Lat == 0 || req.Lng == 0 {
		return nil, ErrValidationFailed
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	id := uuid.New().String()
	typ := req.Type
	if typ == "" {
		typ = "main"
	}

	entrance := &models.Entrance{
		ID:           id,
		HoaID:        req.HoaID,
		Name:         req.Name,
		EntranceType: typ,
		Latitude:     req.Lat,
		Longitude:    req.Lng,
		IsVerified:   false,
		Notes:        req.Notes,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	s.entrances[id] = entrance
	return entrance, nil
}

func (s *EntranceService) VerifyEntrance(id, adminID string) (*models.Entrance, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	e, exists := s.entrances[id]
	if !exists {
		return nil, ErrEntranceNotFound
	}

	now := time.Now()
	e.IsVerified = true
	e.VerifiedBy = &adminID
	e.VerifiedAt = &now
	e.UpdatedAt = now

	return e, nil
}

func (s *EntranceService) GetNearby(lat, lng, radiusKm float64) []*models.Entrance {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var list []*models.Entrance
	for _, e := range s.entrances {
		dist := utils.HaversineKm(lat, lng, e.Latitude, e.Longitude)
		if dist <= radiusKm {
			list = append(list, e)
		}
	}
	return list
}

func (s *EntranceService) GetAllList() []*models.Entrance {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var list []*models.Entrance
	for _, e := range s.entrances {
		list = append(list, e)
	}
	return list
}
