package middleware

import (
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"smartroad-api/internal/utils"
)

type clientLimit struct {
	count     int
	lastReset time.Time
}

type RateLimiter struct {
	window   time.Duration
	max      int
	clients  map[string]*clientLimit
	mu       sync.Mutex
}

func NewRateLimiter(window time.Duration, max int) *RateLimiter {
	rl := &RateLimiter{
		window:  window,
		max:     max,
		clients: make(map[string]*clientLimit),
	}

	// Periodically cleanup stale clients
	go func() {
		for {
			time.Sleep(window * 2)
			rl.mu.Lock()
			now := time.Now()
			for ip, cl := range rl.clients {
				if now.Sub(cl.lastReset) > window {
					delete(rl.clients, ip)
				}
			}
			rl.mu.Unlock()
		}
	}()

	return rl
}

func (rl *RateLimiter) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ip := extractIP(r)

		rl.mu.Lock()
		cl, exists := rl.clients[ip]
		now := time.Now()

		if !exists || now.Sub(cl.lastReset) > rl.window {
			rl.clients[ip] = &clientLimit{
				count:     1,
				lastReset: now,
			}
			rl.mu.Unlock()
			next.ServeHTTP(w, r)
			return
		}

		if cl.count >= rl.max {
			rl.mu.Unlock()
			utils.Error(w, http.StatusTooManyRequests, "RATE_LIMITED", "Too many requests, please try again later")
			return
		}

		cl.count++
		rl.mu.Unlock()

		next.ServeHTTP(w, r)
	})
}

func extractIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		parts := strings.Split(xff, ",")
		return strings.TrimSpace(parts[0])
	}
	if xrip := r.Header.Get("X-Real-IP"); xrip != "" {
		return strings.TrimSpace(xrip)
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err == nil {
		return host
	}
	return r.RemoteAddr
}
