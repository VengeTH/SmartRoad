/**
 * SmartRoad Backend — Realtime Service
 * WebSocket-based pub/sub for live hazard and route updates.
 * Clients connect via WebSocket and subscribe to channels.
 *
 * Channel naming:
 *   hazards:all          — all hazard events
 *   hazards:{id}         — specific hazard
 *   routing:{userId}     — route updates for a user
 *   community:{parentId} — comment/like/rating updates
 */
const { v4: uuidv4 } = require("uuid");
const { logger } = require("../middleware/logger");

let wss = null;
const clients = new Map(); // clientId -> { ws, channels: Set }

/**
 * Initialize WebSocket server on the HTTP server.
 */
function initialize(server) {
  const { WebSocketServer } = require("ws");
  wss = new WebSocketServer({ server, path: "/ws" });

  wss.on("connection", (ws, req) => {
    const clientId = uuidv4();
    const channels = new Set();
    clients.set(clientId, { ws, channels });
    logger.info(`WS client connected: ${clientId}`);

    ws.on("message", (raw) => {
      try {
        const msg = JSON.parse(raw.toString());
        _handleMessage(clientId, msg);
      } catch (err) {
        ws.send(JSON.stringify({ type: "error", message: "Invalid message" }));
      }
    });

    ws.on("close", () => {
      clients.delete(clientId);
      logger.info(`WS client disconnected: ${clientId}`);
    });

    ws.on("error", (err) => {
      logger.error(`WS error [${clientId}]: ${err.message}`);
      clients.delete(clientId);
    });

    ws.send(JSON.stringify({ type: "connected", clientId }));
  });

  logger.info("WebSocket server initialized on /ws");
}

/**
 * Handle incoming WS messages (subscribe/unsubscribe).
 */
function _handleMessage(clientId, msg) {
  const client = clients.get(clientId);
  if (!client) return;

  switch (msg.type) {
    case "subscribe":
      if (msg.channel) {
        client.channels.add(msg.channel);
        client.ws.send(JSON.stringify({ type: "subscribed", channel: msg.channel }));
      }
      break;
    case "unsubscribe":
      if (msg.channel) {
        client.channels.delete(msg.channel);
        client.ws.send(JSON.stringify({ type: "unsubscribed", channel: msg.channel }));
      }
      break;
    case "ping":
      client.ws.send(JSON.stringify({ type: "pong" }));
      break;
    default:
      client.ws.send(JSON.stringify({ type: "error", message: `Unknown type: ${msg.type}` }));
  }
}

/**
 * Broadcast an event to all clients subscribed to a channel.
 */
function broadcast(channel, event) {
  if (!wss) return;
  const payload = JSON.stringify({ type: "event", channel, ...event });
  let count = 0;
  for (const client of clients.values()) {
    if (client.channels.has(channel) || client.channels.has("all")) {
      try {
        client.ws.send(payload);
        count++;
      } catch (_) { /* ignore */ }
    }
  }
  return count;
}

/**
 * Notify when a new hazard is reported.
 */
function notifyHazardCreated(hazard) {
  broadcast("hazards:all", { event: "created", hazard });
}

/**
 * Notify when a hazard is updated.
 */
function notifyHazardUpdated(hazard) {
  broadcast("hazards:all", { event: "updated", hazard });
  broadcast(`hazards:${hazard.id}`, { event: "updated", hazard });
}

/**
 * Notify when a comment is added.
 */
function notifyCommentAdded(parentType, parentId, comment) {
  broadcast(`community:${parentId}`, { event: "comment_added", parentType, parentId, comment });
}

/**
 * Notify when a rating changes.
 */
function notifyRatingChanged(parentType, parentId, summary) {
  broadcast(`community:${parentId}`, { event: "rating_changed", parentType, parentId, summary });
}

module.exports = {
  initialize, broadcast,
  notifyHazardCreated, notifyHazardUpdated,
  notifyCommentAdded, notifyRatingChanged,
};
