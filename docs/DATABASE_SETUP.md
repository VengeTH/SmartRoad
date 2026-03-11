# SmartRoad – Database setup (Supabase)

You can set up the database in one of two ways: **one script** (recommended) or **step-by-step** (separate schema files in order).

---

## Option A: One schema (recommended)

Use the merged schema so you only run a single script:

1. Open your [Supabase](https://supabase.com) project.
2. Go to **SQL Editor**.
3. Open `supabase_schema_merged.sql` from the project root.
4. Copy its full contents and paste into the SQL Editor.
5. Run the script (Run / Execute).

The merged file includes, in the correct order:

- PostGIS + core (profiles, hazards, HOAs, user_stickers)
- Gate access (gate_access_logs, hoa_day_passes, hoas columns)
- Hazard comments
- Places (comments, images, likes, ratings)
- Fuel (cube/earthdistance extensions, stations, price updates, reports, RPCs)
- Routes (saved_routes, purchases, ratings, shares, usage_log)
- Commute AI cache

It is written to be **safe to re-run** (uses `IF NOT EXISTS` / `IF EXISTS` where needed). If a table or object already exists, the script skips or replaces as appropriate.

---

## Option B: Step-by-step (separate files)

If you prefer to run schemas one by one, use this **exact order** (later files depend on earlier ones):

| Order | File | What it adds |
|-------|------|----------------|
| 1 | `supabase_schema.sql` | PostGIS, enums, profiles, hazards, hoas, user_stickers, triggers, RLS |
| 2 | `supabase_gate_access_schema.sql` | pass_mode/radius_meters on hoas, gate_access_logs, hoa_day_passes |
| 3 | `supabase_comments_schema.sql` | hazard_comments |
| 4 | `supabase_places_schema.sql` | place_comments, place_images, place_likes, place_ratings |
| 5 | `supabase_fuel_schema.sql` | fuel_stations, fuel_price_updates, fuel_price_reports, RPCs (needs **cube** + **earthdistance**; enable in Supabase if the script fails) |
| 6 | `supabase_routes_schema.sql` | saved_routes, route_purchases, route_ratings, route_shares, route_usage_log |
| 7 | `supabase/migrations/20260311_create_commute_ai_cache.sql` | commute_ai_cache table |

**Steps:**

1. In Supabase **SQL Editor**, run the contents of **file 1** (`supabase_schema.sql`).
2. Then run **file 2** (`supabase_gate_access_schema.sql`).
3. Continue in order through **file 7**.

Do not skip or reorder; e.g. gate access depends on `hoas` and `user_stickers`, and fuel/places/routes depend on `profiles` and auth.

---

## After setup

- **Storage:** Create a storage bucket named `hazard-images` in the Supabase Dashboard (Storage) if you use hazard image uploads. Set it public and limit MIME types/size as in the comments in `supabase_schema.sql`.
- **Auth:** Sign-up and the `handle_new_user` trigger will create a row in `profiles` for each new user.

---

## Summary

- **Single schema:** Run `supabase_schema_merged.sql` once in the SQL Editor.
- **Step-by-step:** Run the 7 files above in the order 1 → 7.
