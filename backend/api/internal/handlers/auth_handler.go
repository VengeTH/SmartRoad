package handlers

import (
	"encoding/json"
	"errors"
	"net/http"

	"smartroad-api/internal/middleware"
	"smartroad-api/internal/models"
	"smartroad-api/internal/services"
	"smartroad-api/internal/utils"
)

type AuthHandler struct {
	service *services.AuthService
}

func NewAuthHandler(service *services.AuthService) *AuthHandler {
	return &AuthHandler{service: service}
}

func (h *AuthHandler) HandleRegister(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	var req models.RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid request body")
		return
	}

	resp, err := h.service.Register(req)
	if err != nil {
		if errors.Is(err, services.ErrUserExists) {
			utils.Error(w, http.StatusConflict, "EMAIL_EXISTS", "Email already registered")
			return
		}
		if errors.Is(err, services.ErrValidationFailed) {
			utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Email, name, and password (min 6 chars) are required")
			return
		}
		utils.Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to register")
		return
	}

	utils.Success(w, http.StatusCreated, resp)
}

func (h *AuthHandler) HandleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	var req models.LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid request body")
		return
	}

	resp, err := h.service.Login(req)
	if err != nil {
		if errors.Is(err, services.ErrInvalidCreds) {
			utils.Error(w, http.StatusUnauthorized, "INVALID_CREDENTIALS", "Invalid email or password")
			return
		}
		if errors.Is(err, services.ErrValidationFailed) {
			utils.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Email and password are required")
			return
		}
		utils.Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to login")
		return
	}

	utils.Success(w, http.StatusOK, resp)
}

func (h *AuthHandler) HandleMe(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		utils.Error(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed")
		return
	}

	user := middleware.GetUserFromContext(r.Context())
	if user == nil {
		utils.Error(w, http.StatusUnauthorized, "AUTH_REQUIRED", "Authentication required")
		return
	}

	u, err := h.service.GetUserByID(user.ID)
	if err != nil {
		utils.Error(w, http.StatusNotFound, "NOT_FOUND", "User not found")
		return
	}

	utils.Success(w, http.StatusOK, map[string]interface{}{"user": u})
}
