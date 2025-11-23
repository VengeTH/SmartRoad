import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../services/supabase_service.dart";
import "../services/offline_cache_service.dart";
import "../models/hazard.dart";
import "dart:async";

/// * Hazards list provider (for feed)
final hazardsProvider = StateNotifierProvider<HazardsNotifier, AsyncValue<List<Hazard>>>((ref) {
  return HazardsNotifier();
});

class HazardsNotifier extends StateNotifier<AsyncValue<List<Hazard>>> {
  HazardsNotifier() : super(const AsyncValue.loading()) {
    loadHazards();
  }
  
  final _supabaseService = SupabaseService();
  final _cacheService = OfflineCacheService();
  
  Future<void> loadHazards({bool useCache = true}) async {
    try {
      // * Try to load from cache first if offline
      if (useCache) {
        final cached = _cacheService.getCachedHazards();
        if (cached != null && cached.isNotEmpty) {
          state = AsyncValue.data(cached);
        }
      }
      
      // * Load from Supabase
      final hazards = await _supabaseService.getHazards();
      
      // * Cache the results
      await _cacheService.cacheHazards(hazards);
      
      state = AsyncValue.data(hazards);
    } catch (e, stack) {
      // * If online fetch fails, try cache
      final cached = _cacheService.getCachedHazards();
      if (cached != null && cached.isNotEmpty) {
        state = AsyncValue.data(cached);
      } else {
        state = AsyncValue.error(e, stack);
      }
    }
  }
  
  Future<void> refresh() async {
    await loadHazards(useCache: false);
  }
  
  void addHazard(Hazard hazard) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([hazard, ...current]);
  }
  
  void updateHazard(Hazard hazard) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((h) => h.id == hazard.id ? hazard : h).toList(),
    );
  }
  
  void removeHazard(String hazardId) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.where((h) => h.id != hazardId).toList(),
    );
  }
}

/// * Map hazards provider (for map view)
final mapHazardsProvider = StateNotifierProvider<MapHazardsNotifier, List<Hazard>>((ref) {
  return MapHazardsNotifier();
});

class MapHazardsNotifier extends StateNotifier<List<Hazard>> {
  MapHazardsNotifier() : super([]);
  
  final _supabaseService = SupabaseService();
  RealtimeChannel? _channel;
  
  Future<void> loadHazardsInBounds(
    double minLat,
    double minLon,
    double maxLat,
    double maxLon,
  ) async {
    try {
      final hazards = await _supabaseService.getHazardsInBounds(
        minLat,
        minLon,
        maxLat,
        maxLon,
      );
      state = hazards;
      
      // * Subscribe to realtime updates
      _subscribeToRealtime();
    } catch (e) {
      // * Handle error
    }
  }
  
  void _subscribeToRealtime() {
    if (_channel != null) return;
    
    _channel = _supabaseService.subscribeToHazards(
      onInsert: (data) {
        try {
          final hazard = Hazard.fromJson(data);
          state = [...state, hazard];
        } catch (e) {
          // * Handle error
        }
      },
      onUpdate: (data) {
        try {
          final hazard = Hazard.fromJson(data);
          state = state.map((h) => h.id == hazard.id ? hazard : h).toList();
        } catch (e) {
          // * Handle error
        }
      },
      onDelete: (data) {
        try {
          final hazardId = data['id'] as String;
          state = state.where((h) => h.id != hazardId).toList();
        } catch (e) {
          // * Handle error
        }
      },
    );
  }
  
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

