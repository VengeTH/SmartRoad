/**
 * SmartRoad Backend — Village Entrance Service
 * CRUD for verified gate/entrance locations (Priority 6).
 * Solves the delivery rider "scam pin" problem.
 */
const { v4: uuidv4 } = require("uuid");
const { AppError } = require("../middleware/error-handler");

const entrances = new Map();

// Seed demo entrances
_seedDemo();

function _seedDemo() {
  const demo = [
    { hoaId: "hoa-bf-resort", name: "Main Gate", type: "main", lat: 14.4244, lng: 120.9883, verified: true },
    { hoaId: "hoa-bf-resort", name: "Delivery Entrance", type: "delivery", lat: 14.4250, lng: 120.9870, verified: true },
    { hoaId: "hoa-bf-resort", name: "Visitor Gate", type: "visitor", lat: 14.4235, lng: 120.9890, verified: false },
    { hoaId: "hoa-bf-homes", name: "Main Gate", type: "main", lat: 14.5000, lng: 121.0000, verified: true },
    { hoaId: "hoa-bf-homes", name: "Service Entrance", type: "service", lat: 14.5010, lng: 120.9990, verified: false },
  ];
  demo.forEach((e) => {
    const id = uuidv4();
    entrances.set(id, { id, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(), ...e });
  });
}

function getEntrances({ hoaId, type, verified }) {
  let list = Array.from(entrances.values());
  if (hoaId) list = list.filter((e) => e.hoaId === hoaId);
  if (type) list = list.filter((e) => e.type === type);
  if (verified !== undefined) list = list.filter((e) => e.verified === verified);
  return list;
}

function getEntranceById(id) {
  return entrances.get(id) || null;
}

function createEntrance(data) {
  if (!data.hoaId || !data.name || data.lat == null || data.lng == null) {
    throw new AppError("hoaId, name, lat, lng required", 400, "VALIDATION_ERROR");
  }
  const id = uuidv4();
  const entrance = {
    id, hoaId: data.hoaId, name: data.name,
    entranceType: data.entranceType || "main",
    latitude: data.lat, longitude: data.lng,
    isVerified: false, notes: data.notes || null,
    createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
  };
  entrances.set(id, entrance);
  return entrance;
}

function verifyEntrance(id, adminId) {
  const entrance = entrances.get(id);
  if (!entrance) throw new AppError("Entrance not found", 404, "NOT_FOUND");
  entrance.isVerified = true;
  entrance.verifiedBy = adminId;
  entrance.verifiedAt = new Date().toISOString();
  return entrance;
}

module.exports = { getEntrances, getEntranceById, createEntrance, verifyEntrance };
