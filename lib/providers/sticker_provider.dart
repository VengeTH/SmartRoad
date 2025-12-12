/// * Sticker Provider
/// * Riverpod providers for sticker state management
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../models/sticker.dart";
import "../services/sticker_service.dart";
import "auth_provider.dart";

/// * Sticker service provider
final stickerServiceProvider = Provider<StickerService>((ref) {
  return StickerService();
});

/// * User stickers provider
/// * Fetches all stickers for the current user
final userStickersProvider = FutureProvider<List<Sticker>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  
  final stickerService = ref.watch(stickerServiceProvider);
  return await stickerService.getUserStickers(userId);
});

/// * Active user stickers provider
/// * Fetches only valid/active stickers for the current user
final activeUserStickersProvider = FutureProvider<List<Sticker>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  
  final stickerService = ref.watch(stickerServiceProvider);
  return await stickerService.getActiveUserStickers(userId);
});

/// * User sticker IDs provider
/// * Returns list of active sticker IDs (for routing service)
final userStickerIdsProvider = Provider<List<String>>((ref) {
  final stickersAsync = ref.watch(activeUserStickersProvider);
  return stickersAsync.valueOrNull?.map((s) => s.id).toList() ?? [];
});

/// * All HOAs provider
final hoasProvider = FutureProvider<List<HOA>>((ref) async {
  final stickerService = ref.watch(stickerServiceProvider);
  return await stickerService.getAllHOAs();
});


