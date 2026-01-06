import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../models/place_comment.dart";
import "../services/supabase_service.dart";

/// * Comments provider for a specific place (known location)
final placeCommentsProvider = StateNotifierProvider.family<
    PlaceCommentsNotifier,
    AsyncValue<List<PlaceComment>>,
    String>((ref, placeId) {
  return PlaceCommentsNotifier(placeId);
});

class PlaceCommentsNotifier extends StateNotifier<AsyncValue<List<PlaceComment>>> {
  final String placeId;
  final _supabaseService = SupabaseService();
  RealtimeChannel? _channel;

  PlaceCommentsNotifier(this.placeId) : super(const AsyncValue.loading()) {
    loadComments();
  }

  Future<void> loadComments() async {
    try {
      final comments = await _supabaseService.getPlaceComments(placeId);
      state = AsyncValue.data(comments);

      // * Subscribe to realtime updates
      _subscribeToRealtime();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void _subscribeToRealtime() {
    if (_channel != null) return;

    _channel = _supabaseService.subscribeToPlaceComments(
      placeId: placeId,
      onInsert: (data) {
        try {
          final comment = PlaceComment.fromJson(data);
          final current = state.valueOrNull ?? [];
          state = AsyncValue.data([comment, ...current]);
        } catch (_) {
          // * Ignore malformed realtime payloads
        }
      },
      onUpdate: (data) {
        try {
          final comment = PlaceComment.fromJson(data);
          final current = state.valueOrNull ?? [];
          state = AsyncValue.data(
            current.map((c) => c.id == comment.id ? comment : c).toList(),
          );
        } catch (_) {
          // * Ignore malformed realtime payloads
        }
      },
      onDelete: (data) {
        try {
          final commentId = data["id"] as String;
          final current = state.valueOrNull ?? [];
          state = AsyncValue.data(
            current.where((c) => c.id != commentId).toList(),
          );
        } catch (_) {
          // * Ignore malformed realtime payloads
        }
      },
    );
  }

  Future<void> addComment(String text) async {
    try {
      final comment = await _supabaseService.createPlaceComment(
        placeId: placeId,
        text: text,
      );
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data([comment, ...current]);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateComment(String commentId, String text) async {
    try {
      final comment = await _supabaseService.updatePlaceComment(
        commentId: commentId,
        text: text,
      );
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(
        current.map((c) => c.id == commentId ? comment : c).toList(),
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      await _supabaseService.deletePlaceComment(commentId);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(
        current.where((c) => c.id != commentId).toList(),
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

