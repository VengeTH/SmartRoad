package services

import (
	"errors"
	"sync"
	"time"

	"smartroad-api/internal/models"
)

var ErrProfileNotFound = errors.New("PROFILE_NOT_FOUND")

type ProfileService struct {
	profiles map[string]*models.Profile
	mu       sync.RWMutex
}

func NewProfileService() *ProfileService {
	s := &ProfileService{
		profiles: make(map[string]*models.Profile),
	}
	s.seedDemoProfile()
	return s
}

func (s *ProfileService) seedDemoProfile() {
	s.profiles["demo-user-id"] = &models.Profile{
		ID:                "demo-user-id",
		Name:              "Demo User",
		Email:             "demo@smartroad.app",
		PhotoURL:          nil,
		ReporterLevel:     "Novice",
		ValidReportsCount: 0,
		CreatedAt:         time.Now(),
		UpdatedAt:         time.Now(),
	}
}

func (s *ProfileService) GetProfile(userID string) (*models.Profile, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	p, exists := s.profiles[userID]
	if !exists {
		// Return a default profile on the fly if user exists
		return &models.Profile{
			ID:                userID,
			Name:              "SmartRoad User",
			Email:             "",
			ReporterLevel:     "Novice",
			ValidReportsCount: 0,
			CreatedAt:         time.Now(),
			UpdatedAt:         time.Now(),
		}, nil
	}
	return p, nil
}

func (s *ProfileService) UpdateProfile(userID string, req models.UpdateProfileRequest) (*models.Profile, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	p, exists := s.profiles[userID]
	if !exists {
		p = &models.Profile{
			ID:                userID,
			ReporterLevel:     "Novice",
			ValidReportsCount: 0,
			CreatedAt:         time.Now(),
		}
		s.profiles[userID] = p
	}

	if req.Name != nil {
		p.Name = *req.Name
	}
	if req.PhotoURL != nil {
		p.PhotoURL = req.PhotoURL
	}
	p.UpdatedAt = time.Now()

	return p, nil
}
