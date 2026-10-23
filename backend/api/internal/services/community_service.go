package services

import (
	"errors"
	"fmt"
	"math"
	"sort"
	"strings"
	"sync"
	"time"

	"smartroad-api/internal/models"

	"github.com/google/uuid"
)

var (
	ErrCommentNotFound = errors.New("COMMENT_NOT_FOUND")
)

type CommunityService struct {
	comments map[string]*models.Comment
	likes    map[string]time.Time
	ratings  map[string]float64
	mu       sync.RWMutex
}

func NewCommunityService() *CommunityService {
	return &CommunityService{
		comments: make(map[string]*models.Comment),
		likes:    make(map[string]time.Time),
		ratings:  make(map[string]float64),
	}
}

// Comments

func (s *CommunityService) CreateComment(parentType, parentID, userID, userName, text string) (*models.Comment, error) {
	text = strings.TrimSpace(text)
	if parentID == "" || text == "" {
		return nil, ErrValidationFailed
	}

	if parentType == "" {
		parentType = "hazard"
	}
	if userName == "" {
		userName = "Anonymous"
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	id := uuid.New().String()
	c := &models.Comment{
		ID:         id,
		ParentType: parentType,
		ParentID:   parentID,
		UserID:     userID,
		UserName:   userName,
		Text:       text,
		CreatedAt:  time.Now(),
		UpdatedAt:  time.Now(),
	}

	s.comments[id] = c
	return c, nil
}

func (s *CommunityService) GetComments(parentType, parentID string) []*models.Comment {
	if parentType == "" {
		parentType = "hazard"
	}

	s.mu.RLock()
	defer s.mu.RUnlock()

	var list []*models.Comment
	for _, c := range s.comments {
		if c.ParentType == parentType && c.ParentID == parentID {
			list = append(list, c)
		}
	}

	sort.Slice(list, func(i, j int) bool {
		return list[i].CreatedAt.After(list[j].CreatedAt)
	})

	return list
}

func (s *CommunityService) UpdateComment(commentID, userID, text string) (*models.Comment, error) {
	text = strings.TrimSpace(text)
	if text == "" {
		return nil, ErrValidationFailed
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	c, exists := s.comments[commentID]
	if !exists {
		return nil, ErrCommentNotFound
	}
	if c.UserID != userID && userID != "admin" {
		return nil, ErrUnauthorized
	}

	c.Text = text
	c.UpdatedAt = time.Now()
	return c, nil
}

func (s *CommunityService) DeleteComment(commentID, userID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	c, exists := s.comments[commentID]
	if !exists {
		return nil
	}
	if c.UserID != userID && userID != "admin" {
		return ErrUnauthorized
	}

	delete(s.comments, commentID)
	return nil
}

// Likes

func (s *CommunityService) ToggleLike(parentType, parentID, userID string) (bool, int) {
	if parentType == "" {
		parentType = "hazard"
	}
	key := fmt.Sprintf("%s:%s:%s", parentType, parentID, userID)

	s.mu.Lock()
	defer s.mu.Unlock()

	liked := false
	if _, exists := s.likes[key]; exists {
		delete(s.likes, key)
	} else {
		s.likes[key] = time.Now()
		liked = true
	}

	count := s.countLikesLocked(parentType, parentID)
	return liked, count
}

func (s *CommunityService) GetLikeCount(parentType, parentID string) int {
	if parentType == "" {
		parentType = "hazard"
	}

	s.mu.RLock()
	defer s.mu.RUnlock()

	return s.countLikesLocked(parentType, parentID)
}

func (s *CommunityService) countLikesLocked(parentType, parentID string) int {
	prefix := fmt.Sprintf("%s:%s:", parentType, parentID)
	count := 0
	for k := range s.likes {
		if strings.HasPrefix(k, prefix) {
			count++
		}
	}
	return count
}

// Ratings

func (s *CommunityService) SetRating(parentType, parentID, userID string, rating float64) (*models.RatingSummary, error) {
	if rating < 1.0 || rating > 5.0 {
		return nil, ErrValidationFailed
	}
	if parentType == "" {
		parentType = "hazard"
	}
	key := fmt.Sprintf("%s:%s:%s", parentType, parentID, userID)

	s.mu.Lock()
	defer s.mu.Unlock()

	s.ratings[key] = rating
	summary := s.getRatingSummaryLocked(parentType, parentID)
	return &summary, nil
}

func (s *CommunityService) GetRatingSummary(parentType, parentID string) models.RatingSummary {
	if parentType == "" {
		parentType = "hazard"
	}

	s.mu.RLock()
	defer s.mu.RUnlock()

	return s.getRatingSummaryLocked(parentType, parentID)
}

func (s *CommunityService) getRatingSummaryLocked(parentType, parentID string) models.RatingSummary {
	prefix := fmt.Sprintf("%s:%s:", parentType, parentID)
	total := 0.0
	count := 0

	for k, v := range s.ratings {
		if strings.HasPrefix(k, prefix) {
			total += v
			count++
		}
	}

	if count == 0 {
		return models.RatingSummary{AvgRating: 0, RatingsCount: 0}
	}

	avg := math.Round((total/float64(count))*100) / 100
	return models.RatingSummary{
		AvgRating:    avg,
		RatingsCount: count,
	}
}

func (s *CommunityService) GetUserRating(parentType, parentID, userID string) *float64 {
	if parentType == "" {
		parentType = "hazard"
	}
	key := fmt.Sprintf("%s:%s:%s", parentType, parentID, userID)

	s.mu.RLock()
	defer s.mu.RUnlock()

	if r, exists := s.ratings[key]; exists {
		val := r
		return &val
	}
	return nil
}
