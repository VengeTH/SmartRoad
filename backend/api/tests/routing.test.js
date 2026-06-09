/**
 * SmartRoad API — Routing Service Tests
 */
const request = require("supertest");
const app = require("../src/index");

describe("Routing API", () => {
  describe("POST /api/routing/route", () => {
    const validRequest = {
      start: { lat: 14.5995, lon: 120.9842 },
      end: { lat: 14.6760, lon: 121.0437 },
      vehicle: "car",
    };

    test("returns 400 when start is missing", async () => {
      const res = await request(app)
        .post("/api/routing/route")
        .send({ end: validRequest.end, vehicle: "car" });
      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe("VALIDATION_ERROR");
    });

    test("returns 400 when vehicle is missing", async () => {
      const res = await request(app)
        .post("/api/routing/route")
        .send({ start: validRequest.start, end: validRequest.end });
      expect(res.status).toBe(400);
    });

    test("returns 400 for invalid vehicle", async () => {
      const res = await request(app)
        .post("/api/routing/route")
        .send({ ...validRequest, vehicle: "helicopter" });
      expect(res.status).toBe(400);
    });

    test("returns 400 for out-of-range coordinates", async () => {
      const res = await request(app)
        .post("/api/routing/route")
        .send({ start: { lat: 999, lon: 999 }, end: validRequest.end, vehicle: "car" });
      expect(res.status).toBe(400);
    });

    test("accepts valid routing request with all supported vehicles", async () => {
      const vehicles = ["car", "motorcycle", "truck", "pedestrian", "delivery_rider", "flood_safe", "weather_safe", "hoa_access"];
      for (const vehicle of vehicles) {
        const res = await request(app)
          .post("/api/routing/route")
          .send({ ...validRequest, vehicle });
        // Should either return a route (200) or note it's a fallback (200)
        expect(res.status).toBe(200);
        expect(res.body.success).toBe(true);
        expect(res.body.data).toBeDefined();
      }
    });

    test("accepts waypoints", async () => {
      const res = await request(app)
        .post("/api/routing/route")
        .send({
          ...validRequest,
          waypoints: [{ lat: 14.5500, lon: 121.0000 }],
        });
      expect(res.status).toBe(200);
      expect(res.body.data.points.length).toBeGreaterThanOrEqual(2);
    });
  });

  describe("GET /api/routing/vehicles", () => {
    test("returns list of supported vehicles", async () => {
      const res = await request(app).get("/api/routing/vehicles");
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body.data.length).toBeGreaterThanOrEqual(4);
    });
  });

  describe("GET /api/health", () => {
    test("returns health status", async () => {
      const res = await request(app).get("/api/health");
      expect(res.status).toBe(200);
      expect(res.body.status).toBe("ok");
    });
  });
});
