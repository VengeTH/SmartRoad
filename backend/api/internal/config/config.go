package config

import (
	"os"
	"strconv"
	"time"
)

type Config struct {
	Env                   string
	IsDev                 bool
	Port                  string
	GraphHopperURL        string
	GraphHopperTimeout    time.Duration
	GraphHopperMaxRetries int
	JWTSecret             string
	JWTExpiresInDays      int
	RateLimitWindow       time.Duration
	RateLimitMax          int
	LogLevel              string
	CORSOrigin            string
	OpenWeatherMapAPIKey  string
}

func Load() *Config {
	env := getEnv("APP_ENV", getEnv("NODE_ENV", "development"))
	isDev := env != "production"

	port := getEnv("PORT", "3000")

	ghURL := getEnv("GRAPH_HOPPER_URL", "http://graphhopper:8989")
	ghTimeoutMs := getEnvInt("GRAPH_HOPPER_TIMEOUT_MS", 15000)
	ghMaxRetries := getEnvInt("GRAPH_HOPPER_MAX_RETRIES", 2)

	jwtSecret := getEnv("JWT_SECRET", "smartroad-dev-secret-change-in-production")
	jwtExpiresDays := getEnvInt("JWT_EXPIRES_IN_DAYS", 7)

	rlWindowMs := getEnvInt("RATE_LIMIT_WINDOW_MS", 60000)
	rlMax := getEnvInt("RATE_LIMIT_MAX_REQUESTS", 100)

	logLevel := getEnv("LOG_LEVEL", "debug")
	if !isDev && logLevel == "debug" {
		logLevel = "info"
	}

	corsOrigin := getEnv("CORS_ORIGIN", "*")
	owmKey := getEnv("OPENWEATHERMAP_API_KEY", "")

	return &Config{
		Env:                   env,
		IsDev:                 isDev,
		Port:                  port,
		GraphHopperURL:        ghURL,
		GraphHopperTimeout:    time.Duration(ghTimeoutMs) * time.Millisecond,
		GraphHopperMaxRetries: ghMaxRetries,
		JWTSecret:             jwtSecret,
		JWTExpiresInDays:      jwtExpiresDays,
		RateLimitWindow:       time.Duration(rlWindowMs) * time.Millisecond,
		RateLimitMax:          rlMax,
		LogLevel:              logLevel,
		CORSOrigin:            corsOrigin,
		OpenWeatherMapAPIKey:  owmKey,
	}
}

func getEnv(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}

func getEnvInt(key string, defaultVal int) int {
	if val := os.Getenv(key); val != "" {
		if n, err := strconv.Atoi(val); err == nil {
			return n
		}
	}
	return defaultVal
}
