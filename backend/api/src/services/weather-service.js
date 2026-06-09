/**
 * SmartRoad Backend — Weather Service
 * Proxies weather data from Open-Meteo (free) and PAGASA (official PH).
 * Caches responses to reduce upstream calls.
 */
const config = require("../config");
const { AppError } = require("../middleware/error-handler");
const { logger } = require("../middleware/logger");

const cache = new Map();
const CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutes

/**
 * Fetch current weather for a location (Open-Meteo primary, PAGASA fallback).
 */
async function getCurrentWeather(lat, lon) {
  const cacheKey = `current:${lat.toFixed(2)},${lon.toFixed(2)}`;
  const cached = cache.get(cacheKey);
  if (cached && Date.now() - cached.ts < CACHE_TTL_MS) return cached.data;

  let data;
  try {
    data = await _fetchOpenMeteo(lat, lon);
  } catch (err) {
    logger.warn(`Open-Meteo failed, trying PAGASA proxy: ${err.message}`);
    try {
      data = await _fetchPAGASA(lat, lon);
    } catch (err2) {
      logger.error(`PAGASA also failed: ${err2.message}`);
      if (cached) return cached.data;
      throw new AppError("Weather data unavailable", 503, "WEATHER_UNAVAILABLE");
    }
  }

  cache.set(cacheKey, { data, ts: Date.now() });
  return data;
}

async function _fetchOpenMeteo(lat, lon) {
  const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,precipitation,weather_code,wind_speed_10m,relative_humidity_2m,uv_index&timezone=Asia/Manila`;
  const response = await fetch(url, { headers: { "User-Agent": "SmartRoad-API/1.0" } });
  if (!response.ok) throw new Error(`Open-Meteo returned ${response.status}`);
  const json = await response.json();
  const c = json.current || {};
  return _formatResult(lat, lon, c.temperature_2m, c.precipitation, c.weather_code, c.wind_speed_10m, c.relative_humidity_2m, c.uv_index, "open-meteo");
}

/**
 * PAGASA Integration — fetches weather data from the official Philippine
 * Atmospheric, Geophysical and Astronomical Services Administration.
 * Uses the public PAGASA API endpoint for weather bulletins.
 */
async function _fetchPAGASA(lat, lon) {
  // PAGASA provides JSON data at their public API
  // Docs: https://pub.pagasa.dost.gov.ph/pagasa-api
  const url = "https://pub.pagasa.dost.gov.ph/api/weather/v1/philippines";
  const response = await fetch(url, {
    headers: { "User-Agent": "SmartRoad-API/1.0", "Accept": "application/json" },
    signal: AbortSignal.timeout(5000),
  });

  if (!response.ok) throw new Error(`PAGASA returned ${response.status}`);

  const json = await response.json();
  // PAGASA response format varies — try to parse common fields
  const data = json?.data || json?.weather || json;

  // For now, return a basic structure with whatever PAGASA provides
  // Future: parse specific PAGASA bulletin fields
  return {
    latitude: lat,
    longitude: lon,
    temperature: data?.temperature ?? data?.temp ?? null,
    precipitation: data?.rainfall ?? data?.rain ?? null,
    condition: data?.condition ?? data?.description ?? "pagasa_data",
    windSpeed: data?.wind_speed ?? data?.wind ?? null,
    humidity: data?.humidity ?? null,
    source: "pagasa",
    fetchedAt: new Date().toISOString(),
  };
}

function _formatResult(lat, lon, temp, precip, code, wind, humidity, uv, source) {
  return {
    latitude: lat, longitude: lon,
    temperature: temp, precipitation: precip,
    weatherCode: code, windSpeed: wind, humidity, uvIndex: uv,
    condition: _mapWeatherCode(code),
    source,
    fetchedAt: new Date().toISOString(),
  };
}

/**
 * Fetch 3-day weather alerts.
 */
async function getWeatherAlerts(lat, lon) {
  try {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&daily=precipitation_sum,precipitation_probability_max&timezone=Asia/Manila&forecast_days=3`;
    const response = await fetch(url, { headers: { "User-Agent": "SmartRoad-API/1.0" } });
    if (!response.ok) throw new Error(`Open-Meteo returned ${response.status}`);
    const data = await response.json();
    const daily = data.daily || {};
    const alerts = [];
    if (daily.precipitation_sum && daily.precipitation_probability_max) {
      for (let i = 0; i < daily.time.length; i++) {
        if (daily.precipitation_sum[i] > 10 || daily.precipitation_probability_max[i] > 70) {
          alerts.push({
            date: daily.time[i], precipitationMm: daily.precipitation_sum[i],
            probabilityPct: daily.precipitation_probability_max[i],
            severity: daily.precipitation_sum[i] > 50 ? "warning" : "advisory",
          });
        }
      }
    }
    return alerts;
  } catch (err) {
    logger.error(`Weather alerts failed: ${err.message}`);
    return [];
  }
}

function _mapWeatherCode(code) {
  const map = {
    0: "clear", 1: "clear", 2: "partly_cloudy", 3: "overcast",
    45: "foggy", 48: "foggy",
    51: "drizzle", 53: "drizzle", 55: "drizzle",
    61: "light_rain", 63: "moderate_rain", 65: "heavy_rain",
    71: "light_snow", 73: "moderate_snow", 75: "heavy_snow",
    80: "light_showers", 81: "moderate_showers", 82: "heavy_showers",
    95: "thunderstorm", 96: "thunderstorm_hail", 99: "thunderstorm_hail",
  };
  return map[code] || "unknown";
}

module.exports = { getCurrentWeather, getWeatherAlerts };
