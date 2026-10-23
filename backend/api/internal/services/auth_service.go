package services

import (
	"errors"
	"sync"
	"time"

	"smartroad-api/internal/config"
	"smartroad-api/internal/models"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrUserExists       = errors.New("EMAIL_EXISTS")
	ErrInvalidCreds     = errors.New("INVALID_CREDENTIALS")
	ErrValidationFailed = errors.New("VALIDATION_ERROR")
	ErrUserNotFound     = errors.New("USER_NOT_FOUND")
)

type AuthService struct {
	cfg   *config.Config
	users map[string]*models.User
	mu    sync.RWMutex
}

func NewAuthService(cfg *config.Config) *AuthService {
	s := &AuthService{
		cfg:   cfg,
		users: make(map[string]*models.User),
	}
	s.seedDemoUsers()
	return s
}

func (s *AuthService) seedDemoUsers() {
	demoHash, _ := bcrypt.GenerateFromPassword([]byte("DemoPass123!"), bcrypt.DefaultCost)
	demoID := "demo-user-id"
	s.users["demo@smartroad.app"] = &models.User{
		ID:        demoID,
		Email:     "demo@smartroad.app",
		Name:      "Demo User",
		Password:  string(demoHash),
		CreatedAt: time.Now(),
	}
}

func (s *AuthService) Register(req models.RegisterRequest) (*models.AuthResponse, error) {
	if req.Email == "" || req.Password == "" || req.Name == "" {
		return nil, ErrValidationFailed
	}
	if len(req.Password) < 6 {
		return nil, ErrValidationFailed
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.users[req.Email]; exists {
		return nil, ErrUserExists
	}

	hashed, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	user := &models.User{
		ID:        uuid.New().String(),
		Email:     req.Email,
		Name:      req.Name,
		Password:  string(hashed),
		CreatedAt: time.Now(),
	}

	s.users[req.Email] = user

	token, err := s.generateToken(user)
	if err != nil {
		return nil, err
	}

	return &models.AuthResponse{
		User:  user.Public(),
		Token: token,
	}, nil
}

func (s *AuthService) Login(req models.LoginRequest) (*models.AuthResponse, error) {
	if req.Email == "" || req.Password == "" {
		return nil, ErrValidationFailed
	}

	s.mu.RLock()
	user, exists := s.users[req.Email]
	s.mu.RUnlock()

	if !exists {
		return nil, ErrInvalidCreds
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)); err != nil {
		return nil, ErrInvalidCreds
	}

	token, err := s.generateToken(user)
	if err != nil {
		return nil, err
	}

	return &models.AuthResponse{
		User:  user.Public(),
		Token: token,
	}, nil
}

func (s *AuthService) GetUserByID(id string) (*models.UserPublic, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	for _, u := range s.users {
		if u.ID == id {
			pub := u.Public()
			return &pub, nil
		}
	}
	return nil, ErrUserNotFound
}

func (s *AuthService) generateToken(user *models.User) (string, error) {
	claims := &models.Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   user.ID,
			ExpiresAt: jwt.NewNumericDate(time.Now().AddDate(0, 0, s.cfg.JWTExpiresInDays)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
		Email: user.Email,
		Name:  user.Name,
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(s.cfg.JWTSecret))
}
