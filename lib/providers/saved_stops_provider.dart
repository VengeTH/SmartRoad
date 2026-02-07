import "dart:convert";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:hive/hive.dart";

import "../models/saved_commute_stop.dart";
import "../models/commute_state.dart";

/// * Saved commute stops provider
final savedStopsProvider = StateNotifierProvider<SavedStopsNotifier, List<SavedCommuteStop>>((ref) {
  return SavedStopsNotifier();
});

/// * Provider for stops sorted by use count (most used first)
final popularStopsProvider = Provider<List<SavedCommuteStop>>((ref) {
  final stops = ref.watch(savedStopsProvider);
  final sorted = List<SavedCommuteStop>.from(stops);
  sorted.sort((a, b) => b.useCount.compareTo(a.useCount));
  return sorted;
});

/// * Provider for stops filtered by category
final stopsByCategoryProvider = Provider.family<List<SavedCommuteStop>, StopCategory>((ref, category) {
  final stops = ref.watch(savedStopsProvider);
  return stops.where((s) => s.category == category).toList();
});

/// * Provider for recent stops (sorted by most recent use)
final recentStopsProvider = Provider<List<SavedCommuteStop>>((ref) {
  final stops = ref.watch(savedStopsProvider);
  final sorted = List<SavedCommuteStop>.from(stops);
  sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sorted.take(5).toList();
});

/// * Saved stops state notifier  
/// * Uses Hive for local persistence
class SavedStopsNotifier extends StateNotifier<List<SavedCommuteStop>> {
  SavedStopsNotifier() : super([]) {
    _loadFromStorage();
  }
  
  static const String _boxName = "saved_commute_stops";
  Box? _box;
  
  /// * Load saved stops from storage
  Future<void> _loadFromStorage() async {
    try {
      _box = await Hive.openBox(_boxName);
      final json = _box?.get("stops");
      if (json != null) {
        final List<dynamic> decoded = jsonDecode(json as String);
        final stops = decoded
            .map((e) => SavedCommuteStop.fromJson(e as Map<String, dynamic>))
            .toList();
        state = stops;
      }
    } catch (e) {
      // * Failed to load, start with empty
      state = [];
    }
  }
  
  /// * Save stops to storage
  Future<void> _saveToStorage() async {
    try {
      if (_box == null) {
        _box = await Hive.openBox(_boxName);
      }
      final json = jsonEncode(state.map((s) => s.toJson()).toList());
      await _box?.put("stops", json);
    } catch (e) {
      // * Failed to save
    }
  }
  
  /// * Add a new saved stop
  Future<void> addStop(SavedCommuteStop stop) async {
    // * Check for duplicate name
    final existing = state.where((s) => s.name == stop.name).toList();
    if (existing.isNotEmpty) {
      // * Update existing
      await updateStop(existing.first.id, stop);
      return;
    }
    
    state = [...state, stop];
    await _saveToStorage();
  }
  
  /// * Remove a saved stop
  Future<void> removeStop(String id) async {
    state = state.where((s) => s.id != id).toList();
    await _saveToStorage();
  }
  
  /// * Update a saved stop
  Future<void> updateStop(String id, SavedCommuteStop updatedStop) async {
    state = state.map((s) {
      if (s.id == id) {
        return updatedStop.copyWith(id: id);
      }
      return s;
    }).toList();
    await _saveToStorage();
  }
  
  /// * Increment use count for a stop
  Future<void> incrementUseCount(String id) async {
    state = state.map((s) {
      if (s.id == id) {
        return s.incrementUseCount();
      }
      return s;
    }).toList();
    await _saveToStorage();
  }
  
  /// * Get stop by ID
  SavedCommuteStop? getStopById(String id) {
    try {
      return state.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
  
  /// * Check if a stop exists with given name
  bool hasStopWithName(String name) {
    return state.any((s) => s.name.toLowerCase() == name.toLowerCase());
  }
  
  /// * Clear all saved stops
  Future<void> clearAll() async {
    state = [];
    await _saveToStorage();
  }
  
  /// * Get categories that have stops
  List<StopCategory> get usedCategories {
    return StopCategory.values
        .where((c) => state.any((s) => s.category == c))
        .toList();
  }
  
  /// * Get count by category
  Map<StopCategory, int> get countByCategory {
    final counts = <StopCategory, int>{};
    for (final category in StopCategory.values) {
      counts[category] = state.where((s) => s.category == category).length;
    }
    return counts;
  }
}

