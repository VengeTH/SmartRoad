package services

import (
	"errors"
	"fmt"
	"sync"
	"time"

	"smartroad-api/internal/models"

	"github.com/google/uuid"
)

var ErrHOANotFound = errors.New("HOA_NOT_FOUND")

type HOAService struct {
	hoas map[string]*models.HOA
	mu   sync.RWMutex
}

func NewHOAService() *HOAService {
	s := &HOAService{
		hoas: make(map[string]*models.HOA),
	}
	s.seedDemoHOAs()
	return s
}

func (s *HOAService) seedDemoHOAs() {
	demos := []models.HOA{
		{
			ID:          "hoa-bf-resort",
			Name:        "BF Resort",
			Description: "BF Resort Village",
			Latitude:    14.4244,
			Longitude:   120.9883,
			AccessType:  "public_shortcut",
			IsActive:    true,
			CreatedAt:   time.Now(),
		},
		{
			ID:          "hoa-bf-homes",
			Name:        "BF Homes",
			Description: "BF Homes Parañaque",
			Latitude:    14.5000,
			Longitude:   121.0000,
			AccessType:  "residents_only",
			IsActive:    true,
			CreatedAt:   time.Now(),
		},
	}

	for _, h := range demos {
		cpy := h
		s.hoas[h.ID] = &cpy
	}
}

func (s *HOAService) GetHOAs() []*models.HOA {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var list []*models.HOA
	for _, h := range s.hoas {
		if h.IsActive {
			list = append(list, h)
		}
	}
	return list
}

func (s *HOAService) GetHOAByID(id string) (*models.HOA, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	h, exists := s.hoas[id]
	if !exists {
		return nil, ErrHOANotFound
	}
	return h, nil
}

func (s *HOAService) RegisterHOA(userID string, req models.RegisterHOARequest) (*models.HOA, error) {
	if req.Name == "" {
		return nil, ErrValidationFailed
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	id := fmt.Sprintf("hoa-%s", uuid.New().String()[:8])
	access := req.AccessType
	if access == "" {
		access = "public_shortcut"
	}

	hoa := &models.HOA{
		ID:           id,
		Name:         req.Name,
		Description:  req.Description,
		Latitude:     req.Latitude,
		Longitude:    req.Longitude,
		AccessType:   access,
		IsActive:     true,
		RegisteredBy: userID,
		CreatedAt:    time.Now(),
	}

	s.hoas[id] = hoa
	return hoa, nil
}
