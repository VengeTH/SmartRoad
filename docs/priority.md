# SmartRoad — Priority Implementation Checklist

> **The Heedful · Flagship Project**  
> This document tracks SmartRoad's feature priorities from most critical to nice-to-have.  
> Items marked ✅ are implemented. Items marked ❌ need implementation.

---

## Priority 1: PostGIS (Next Critical Component)

SmartRoad's competitive advantage is not routing itself.

Google Maps, Waze, and GraphHopper already route.

SmartRoad's value comes from:

- Flood zones
- Hazard reports
- Scam pins
- Village entrances
- HOA restrictions
- Community shortcuts

You need PostGIS for this.

### Checklist

- [x] Install PostGIS extension
- [x] Create SmartRoad database schema
- [x] Create `roads` table
- [x] Create `flood_zones` table
- [x] Create `hazard_reports` table
- [x] Create `village_entrances` table
- [x] Create `restricted_roads` table
- [x] Create `user_stickers` table
- [x] Create `community_routes` table

---

## Priority 2: Authentication

Before users can report hazards.

### Checklist

- [x] Register
- [x] Login
- [x] JWT Authentication
- [x] User roles
- [x] Admin roles
- [x] Rider profiles

---

## Priority 3: Hazard Reporting

This should be one of the first real SmartRoad features.

### Checklist

- [x] Report flood
- [x] Report accident
- [x] Report road closure
- [x] Report fallen tree
- [x] Report traffic
- [x] Upload image
- [x] GPS coordinates
- [x] Report verification

---

## Priority 4: Map Display

If not already done.

### Checklist

- [ ] MapLibre
- [x] OpenStreetMap tiles
- [x] User location
- [x] Route rendering
- [x] Hazard markers
- [ ] Flood overlays

---

## Priority 5: Smart Routing Logic

Before HOA routing.

### Checklist

- [x] Request route from GraphHopper
- [x] Check route against flood zones
- [x] Check route against hazards
- [x] Generate safer alternative
- [x] Return modified route

> This is where SmartRoad starts becoming unique.

---

## Priority 6: Village Entrance Intelligence

One of your strongest differentiators.

### Checklist

- [x] Village database
- [x] Entrance database
- [x] Gate locations
- [x] Community reports
- [x] Entrance verification

> This solves the delivery rider "scam pin" problem.

---

## Priority 7: HOA Sticker System

After everything above.

### Checklist

- [x] Digital sticker wallet
- [x] HOA registration
- [x] Sticker ownership
- [x] Sticker verification
- [x] Restricted-road routing

---

## Priority 8: Weather Intelligence

### Checklist

- [x] PAGASA integration
- [x] RainViewer integration
- [x] Rain overlays
- [ ] Flood prediction
- [ ] Weather-aware routing

---

> *"Be Heedful on the Road"* — **SmartRoad**, a product of **The Heedful** 🇵🇭

