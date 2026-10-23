# Multi-stage build for SmartRoad Go Backend API
FROM golang:1.24-alpine AS builder

WORKDIR /app

RUN apk add --no-cache git ca-certificates tzdata

# Copy dependency definitions
COPY go.mod go.sum ./
RUN go mod download

# Copy source tree
COPY . .

# Build static Go binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o /app/smartroad-api ./cmd/server

# Minimal runtime image
FROM alpine:3.20

WORKDIR /app

RUN apk add --no-cache ca-certificates wget tzdata

COPY --from=builder /app/smartroad-api /app/smartroad-api

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1

ENTRYPOINT ["/app/smartroad-api"]

