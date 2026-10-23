package utils

import (
	"encoding/json"
	"net/http"
)

type APIError struct {
	Code    string      `json:"code"`
	Message string      `json:"message"`
	Details interface{} `json:"details,omitempty"`
}

type Response struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   *APIError   `json:"error,omitempty"`
	Note    string      `json:"note,omitempty"`
}

func JSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}

func Success(w http.ResponseWriter, status int, data interface{}) {
	JSON(w, status, Response{
		Success: true,
		Data:    data,
	})
}

func SuccessWithNote(w http.ResponseWriter, status int, data interface{}, note string) {
	JSON(w, status, Response{
		Success: true,
		Data:    data,
		Note:    note,
	})
}

func Error(w http.ResponseWriter, status int, code, message string, details ...interface{}) {
	var detail interface{}
	if len(details) > 0 {
		detail = details[0]
	}
	JSON(w, status, Response{
		Success: false,
		Error: &APIError{
			Code:    code,
			Message: message,
			Details: detail,
		},
	})
}
