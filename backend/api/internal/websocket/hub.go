package websocket

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for dev/flutter client
	},
}

type Client struct {
	ID       string
	Hub      *Hub
	Conn     *websocket.Conn
	Send     chan []byte
	Channels map[string]bool
	mu       sync.RWMutex
}

type Hub struct {
	clients    map[string]*Client
	broadcast  chan BroadcastMessage
	register   chan *Client
	unregister chan *Client
	mu         sync.RWMutex
}

type BroadcastMessage struct {
	Channel string
	Payload []byte
}

type IncomingMessage struct {
	Type    string `json:"type"`
	Channel string `json:"channel,omitempty"`
}

var globalHub *Hub
var once sync.Once

func GetHub() *Hub {
	once.Do(func() {
		globalHub = &Hub{
			clients:    make(map[string]*Client),
			broadcast:  make(chan BroadcastMessage, 256),
			register:   make(chan *Client),
			unregister: make(chan *Client),
		}
		go globalHub.run()
	})
	return globalHub
}

func (h *Hub) run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client.ID] = client
			h.mu.Unlock()
			log.Printf("WS client registered: %s", client.ID)

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client.ID]; ok {
				delete(h.clients, client.ID)
				close(client.Send)
			}
			h.mu.Unlock()
			log.Printf("WS client unregistered: %s", client.ID)

		case msg := <-h.broadcast:
			h.mu.RLock()
			for _, client := range h.clients {
				client.mu.RLock()
				subscribed := client.Channels[msg.Channel] || client.Channels["all"]
				client.mu.RUnlock()

				if subscribed {
					select {
					case client.Send <- msg.Payload:
					default:
						// Buffer full
					}
				}
			}
			h.mu.RUnlock()
		}
	}
}

func (h *Hub) Broadcast(channel string, event interface{}) {
	payload, err := json.Marshal(map[string]interface{}{
		"type":    "event",
		"channel": channel,
		"data":    event,
	})
	if err != nil {
		return
	}
	h.broadcast <- BroadcastMessage{
		Channel: channel,
		Payload: payload,
	}
}

func HandleWebSocket(hub *Hub, w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("WS upgrade error: %v", err)
		return
	}

	clientID := uuid.New().String()
	client := &Client{
		ID:       clientID,
		Hub:      hub,
		Conn:     conn,
		Send:     make(chan []byte, 64),
		Channels: make(map[string]bool),
	}

	hub.register <- client

	// Send initial connected message
	initMsg, _ := json.Marshal(map[string]string{
		"type":     "connected",
		"clientId": clientID,
	})
	_ = conn.WriteMessage(websocket.TextMessage, initMsg)

	go client.writePump()
	go client.readPump()
}

func (c *Client) readPump() {
	defer func() {
		c.Hub.unregister <- c
		c.Conn.Close()
	}()

	for {
		_, message, err := c.Conn.ReadMessage()
		if err != nil {
			break
		}

		var in IncomingMessage
		if err := json.Unmarshal(message, &in); err != nil {
			errMsg, _ := json.Marshal(map[string]string{"type": "error", "message": "Invalid message"})
			c.Send <- errMsg
			continue
		}

		switch in.Type {
		case "subscribe":
			if in.Channel != "" {
				c.mu.Lock()
				c.Channels[in.Channel] = true
				c.mu.Unlock()
				ack, _ := json.Marshal(map[string]string{"type": "subscribed", "channel": in.Channel})
				c.Send <- ack
			}
		case "unsubscribe":
			if in.Channel != "" {
				c.mu.Lock()
				delete(c.Channels, in.Channel)
				c.mu.Unlock()
				ack, _ := json.Marshal(map[string]string{"type": "unsubscribed", "channel": in.Channel})
				c.Send <- ack
			}
		case "ping":
			pong, _ := json.Marshal(map[string]string{"type": "pong"})
			c.Send <- pong
		}
	}
}

func (c *Client) writePump() {
	defer c.Conn.Close()

	for msg := range c.Send {
		if err := c.Conn.WriteMessage(websocket.TextMessage, msg); err != nil {
			break
		}
	}
}
