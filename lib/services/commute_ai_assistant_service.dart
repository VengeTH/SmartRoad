import "dart:convert";

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";

import "../core/config/env.dart";
import "../models/commute_state.dart";
import "app_preferences_service.dart";
import "supabase_service.dart";

/// * Optional augmentation from AI for commute guide text only.
/// * Used when deterministic quality is low; never for routing, GTFS, fare, or geometry.
class CommuteGuideAugmentation {
  final String? whereToBoard;
  final String? whatToTake;
  final String? notes;

  const CommuteGuideAugmentation({
    this.whereToBoard,
    this.whatToTake,
    this.notes,
  });

  bool get isEmpty =>
      (whereToBoard == null || whereToBoard!.trim().isEmpty) &&
      (whatToTake == null || whatToTake!.trim().isEmpty) &&
      (notes == null || notes!.trim().isEmpty);
}

/// * SmartRoad commute AI assistant: Gemini 2.5 Flash for guide text only.
/// * Not used for routing, GTFS planning, fare calculation, or map geometry.
/// * Fallback when AI is down: returns null so caller keeps deterministic guide.
class CommuteAiAssistantService {
  CommuteAiAssistantService._();

  static final CommuteAiAssistantService _instance =
      CommuteAiAssistantService._();
  static CommuteAiAssistantService get instance => _instance;

  static const String _modelName = "gemini-2.5-flash";
  static const String _baseUrl =
      "https://generativelanguage.googleapis.com/v1beta";
  static const Duration _timeout = Duration(seconds: 15);

  /// * Circuit breaker: skip AI for this duration after [failureThreshold] consecutive failures.
  static const Duration _circuitCooldown = Duration(minutes: 5);
  static const int failureThreshold = 3;

  int _consecutiveFailures = 0;
  DateTime? _circuitOpenUntil;

  /// * Per-key failure cache: skip AI for this key for a short time to avoid console spam.
  final Map<String, DateTime> _keyFailureUntil = {};
  static const Duration _keyFailureCooldown = Duration(minutes: 2);

  static const int _cacheTtlMinutes = 24 * 60;

  /// * Returns augmentation for guide text, or null if API key missing, circuit open, timeout, or error.
  /// * Uses L1 local then L2 Supabase cache before calling Gemini.
  Future<CommuteGuideAugmentation?> getGuideAugmentation({
    required String destinationName,
    required VehicleType vehicleType,
    required double distanceKm,
    required String currentWhereToBoard,
    required String currentWhatToTake,
    required String currentNotes,
    double? originLat,
    double? originLon,
    double? destinationLat,
    double? destinationLon,
  }) async {
    final cacheKey = _normalizeCacheKey(
      destinationName,
      vehicleType,
      distanceKm,
    );

    final l1 = await AppPreferencesService().getCommuteAiCacheEntry(cacheKey);
    if (l1 != null) {
      final aug = _payloadToAugmentation(l1);
      if (aug != null && !aug.isEmpty) return aug;
    }

    final l2 = await SupabaseService().getCommuteAiCache(cacheKey);
    if (l2 != null) {
      final aug = _payloadToAugmentation(l2);
      if (aug != null && !aug.isEmpty) {
        await AppPreferencesService().setCommuteAiCacheEntry(
          cacheKey,
          l2,
          DateTime.now().add(const Duration(minutes: _cacheTtlMinutes)),
        );
        return aug;
      }
    }

    final apiKey = Env.geminiApiKey;
    if (apiKey.isEmpty) {
      if (kDebugMode)
        debugPrint("[CommuteAiAssistant] GEMINI_API_KEY not set; skipping AI.");
      return null;
    }
    if (kDebugMode && apiKey.length >= 4) {
      debugPrint(
        "[CommuteAiAssistant] GEMINI_API_KEY present (${apiKey.substring(0, 4)}...); using AI.",
      );
    }

    if (_isCircuitOpen()) {
      if (kDebugMode)
        debugPrint("[CommuteAiAssistant] Circuit open; skipping AI.");
      return null;
    }
    if (_isKeyInFailureCooldown(cacheKey)) {
      if (kDebugMode)
        debugPrint(
          "[CommuteAiAssistant] Recent failure for this guide key; skipping to avoid spam.",
        );
      return null;
    }

    final prompt = _buildPrompt(
      destinationName: destinationName,
      vehicleType: vehicleType,
      distanceKm: distanceKm,
      currentWhereToBoard: currentWhereToBoard,
      currentWhatToTake: currentWhatToTake,
      currentNotes: currentNotes,
      originLat: originLat,
      originLon: originLon,
      destinationLat: destinationLat,
      destinationLon: destinationLon,
    );

    try {
      final dio = Dio(
        BaseOptions(connectTimeout: _timeout, receiveTimeout: _timeout),
      );
      final url = "$_baseUrl/models/$_modelName:generateContent?key=$apiKey";
      final response = await dio.post(
        url,
        data: {
          "contents": [
            {
              "parts": [
                {"text": prompt},
              ],
            },
          ],
          "generationConfig": {"maxOutputTokens": 512, "temperature": 0.3},
        },
        options: Options(
          headers: {"Content-Type": "application/json"},
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
        ),
      );

      if (response.statusCode != 200) {
        _recordFailure();
        _recordKeyFailure(cacheKey);
        if (kDebugMode) {
          final body = response.data;
          final bodyStr =
              body is Map ? body.toString() : (body?.toString() ?? "null");
          debugPrint(
            "[CommuteAiAssistant] API error: status=${response.statusCode} body=$bodyStr",
          );
        }
        final code = response.statusCode;
        if (code != null && code >= 400 && code < 500) {
          _circuitOpenUntil = DateTime.now().add(_circuitCooldown);
        }
        return null;
      }

      final data = response.data as Map<String, dynamic>?;
      final candidates = data?["candidates"] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        _recordFailure();
        return null;
      }

      final content =
          (candidates.first as Map<String, dynamic>)["content"]
              as Map<String, dynamic>?;
      final parts = content?["parts"] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        _recordFailure();
        return null;
      }

      final text = (parts.first as Map<String, dynamic>)["text"] as String?;
      if (text == null || text.trim().isEmpty) {
        _recordFailure();
        return null;
      }

      if (kDebugMode) {
        debugPrint(
          "[CommuteAiAssistant] Raw AI response (${text.length} chars): ${text.length > 300 ? "${text.substring(0, 300)}…" : text}",
        );
      }

      final aug = _parseAugmentation(text);
      if (aug != null && !aug.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            "[CommuteAiAssistant] AI augmentation applied — board=${aug.whereToBoard?.substring(0, (aug.whereToBoard?.length ?? 0).clamp(0, 60))}",
          );
        }
        _consecutiveFailures = 0;
        final payload = _augmentationToPayload(aug);
        await SupabaseService().upsertCommuteAiCache(
          cacheKey,
          payload,
          ttlMinutes: _cacheTtlMinutes,
        );
        await AppPreferencesService().setCommuteAiCacheEntry(
          cacheKey,
          payload,
          DateTime.now().add(const Duration(minutes: _cacheTtlMinutes)),
        );
        return aug;
      }
      if (kDebugMode) {
        debugPrint(
          "[CommuteAiAssistant] AI returned 200 but augmentation was empty or unparseable.",
        );
      }
      return null;
    } on DioException catch (e) {
      _recordFailure();
      _recordKeyFailure(cacheKey);
      if (kDebugMode) {
        final status = e.response?.statusCode;
        final data = e.response?.data;
        final dataStr =
            data is Map ? data.toString() : (data?.toString() ?? "null");
        debugPrint(
          "[CommuteAiAssistant] DioException: status=$status response.data=$dataStr message=${e.message}",
        );
      }
      final status = e.response?.statusCode;
      if (status != null && status >= 400 && status < 500) {
        _circuitOpenUntil = DateTime.now().add(_circuitCooldown);
      }
      return null;
    } catch (e) {
      _recordFailure();
      _recordKeyFailure(cacheKey);
      if (kDebugMode) debugPrint("[CommuteAiAssistant] Error: $e");
      return null;
    }
  }

  bool _isKeyInFailureCooldown(String cacheKey) {
    final until = _keyFailureUntil[cacheKey];
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _keyFailureUntil.remove(cacheKey);
      return false;
    }
    return true;
  }

  void _recordKeyFailure(String cacheKey) {
    _keyFailureUntil[cacheKey] = DateTime.now().add(_keyFailureCooldown);
  }

  String _normalizeCacheKey(
    String destinationName,
    VehicleType vehicleType,
    double distanceKm,
  ) {
    final dest = destinationName.trim().toLowerCase().replaceAll(
      RegExp(r"\s+"),
      " ",
    );
    final band =
        distanceKm < 10
            ? "0_10"
            : distanceKm < 25
            ? "10_25"
            : distanceKm < 50
            ? "25_50"
            : "50_";
    return "dest:${dest.isEmpty ? "unknown" : dest}:vehicle:${vehicleType.name}:band:$band";
  }

  Map<String, dynamic> _augmentationToPayload(CommuteGuideAugmentation aug) {
    return {
      "whereToBoard": aug.whereToBoard,
      "whatToTake": aug.whatToTake,
      "notes": aug.notes,
    };
  }

  CommuteGuideAugmentation? _payloadToAugmentation(
    Map<String, dynamic> payload,
  ) {
    try {
      return CommuteGuideAugmentation(
        whereToBoard: payload["whereToBoard"] as String?,
        whatToTake: payload["whatToTake"] as String?,
        notes: payload["notes"] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isCircuitOpen() {
    final until = _circuitOpenUntil;
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _circuitOpenUntil = null;
      _consecutiveFailures = 0;
      return false;
    }
    return true;
  }

  void _recordFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= failureThreshold) {
      _circuitOpenUntil = DateTime.now().add(_circuitCooldown);
      if (kDebugMode) {
        debugPrint(
          "[CommuteAiAssistant] Circuit open until $_circuitOpenUntil",
        );
      }
    }
  }

  String _buildPrompt({
    required String destinationName,
    required VehicleType vehicleType,
    required double distanceKm,
    required String currentWhereToBoard,
    required String currentWhatToTake,
    required String currentNotes,
    double? originLat,
    double? originLon,
    double? destinationLat,
    double? destinationLon,
  }) {
    const rules =
        "You are SmartRoad commute assistant for Philippine commuting. "
        "Give practical and concrete suggestions for where to board and what to take. "
        "Do not invent exact signboards or exact route numbers if uncertain. "
        "If uncertain, use likely terminals/transfer strategy and say 'verify with driver/conductor'. ";
    final context =
        "Destination: $destinationName. Vehicle: ${vehicleType.label}. Distance: ~${distanceKm.toStringAsFixed(0)} km. "
        "OriginCoord: ${originLat?.toStringAsFixed(5) ?? "unknown"}, ${originLon?.toStringAsFixed(5) ?? "unknown"}. "
        "DestinationCoord: ${destinationLat?.toStringAsFixed(5) ?? "unknown"}, ${destinationLon?.toStringAsFixed(5) ?? "unknown"}. ";
    const output =
        "Reply with JSON only, no markdown: {\"whereToBoard\":\"...\", \"whatToTake\":\"...\", \"notes\":\"...\"}. "
        "Keep each field 1-2 short sentences. Include transfer sequence when distance is long. Mention cost-saving walking tip when safe.";
    return "$rules$context Current suggestions: board=\"$currentWhereToBoard\", take=\"$currentWhatToTake\", notes=\"$currentNotes\". $output";
  }

  CommuteGuideAugmentation? _parseAugmentation(String text) {
    try {
      final cleaned = text.trim();
      final start = cleaned.indexOf("{");
      final end = cleaned.lastIndexOf("}");
      if (start < 0 || end <= start) return null;
      final jsonStr = cleaned.substring(start, end + 1);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final whereToBoard = map["whereToBoard"] as String?;
      final whatToTake = map["whatToTake"] as String?;
      final notes = map["notes"] as String?;
      return CommuteGuideAugmentation(
        whereToBoard:
            whereToBoard?.trim().isEmpty == true ? null : whereToBoard?.trim(),
        whatToTake:
            whatToTake?.trim().isEmpty == true ? null : whatToTake?.trim(),
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      );
    } catch (_) {
      return null;
    }
  }
}
