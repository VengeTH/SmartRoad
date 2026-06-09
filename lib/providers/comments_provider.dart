import "package:flutter_riverpod/flutter_riverpod.dart";
import "dart:async";
import "../services/supabase_service.dart";
import "../models/hazard_comment.dart";

/// * Comments provider for a specific hazard
final hazardCommentsProvider = StateNotifierProvider.family<HazardCommentsNotifier, AsyncValue<List<HazardComment>>, String>((ref, hazardId) {
  return HazardCommentsNotifier(hazardId);
});

class HazardCommentsNotifier extends StateNotifier<AsyncValue<List<HazardComment>>> {
  final String hazardId;
  final _supabaseService = SupabaseService();
  dynamic _channel; // * Realtime channel (backend WebSocket)
  
  HazardCommentsNotifier(this.hazardId) : super(const AsyncValue.loading()) {
    loadComments();
  }
  
  Future<void> loadComments() async {
    try {
      final comments = await _supabaseService.getHazardComments(hazardId);
      state = AsyncValue.data(comments);
      
      // * Subscribe to realtime updates
      _subscribeToRealtime();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  void _subscribeToRealtime() {
    if (_channel != null) return;
    
    _channel = _supabaseService.subscribeToComments(
      hazardId: hazardId,
      onInsert: (data) {
        try {
          final comment = HazardComment.fromJson(data);
          final current = state.valueOrNull ?? [];
          state = AsyncValue.data([comment, ...current]);
        } catch (e) {
          // * Handle error
        }
      },
      onUpdate: (data) {
        try {
          final comment = HazardComment.fromJson(data);
          final current = state.valueOrNull ?? [];
          state = AsyncValue.data(
            current.map((c) => c.id == comment.id ? comment : c).toList(),
          );
        } catch (e) {
          // * Handle error
        }
      },
      onDelete: (data) {
        try {
          final commentId = data['id'] as String;
          final current = state.valueOrNull ?? [];
          state = AsyncValue.data(
            current.where((c) => c.id != commentId).toList(),
          );
        } catch (e) {
          // * Handle error
        }
      },
    );
  }
  
  Future<void> addComment(String text) async {
    try {
      final comment = await _supabaseService.createComment(
        hazardId: hazardId,
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
      final comment = await _supabaseService.updateComment(
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
      await _supabaseService.deleteComment(commentId);
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
