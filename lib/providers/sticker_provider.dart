/// * Sticker Providers
/// * Riverpod providers for sticker and HOA data
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
  if (userId == null) {
    return [];
  }
  
  final stickerService = ref.watch(stickerServiceProvider);
  return await stickerService.getUserStickers(userId);
});

/// * HOAs provider
/// * Fetches all active HOAs
final hoasProvider = FutureProvider<List<HOA>>((ref) async {
  final stickerService = ref.watch(stickerServiceProvider);
  return await stickerService.getAllHOAs();
});

/// * Active user stickers provider
/// * Fetches only valid (active and not expired) stickers for the current user
final activeUserStickersProvider = FutureProvider<List<Sticker>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return [];
  }
  
  final stickerService = ref.watch(stickerServiceProvider);
  return await stickerService.getActiveUserStickers(userId);
});

/// * User sticker IDs provider
/// * Returns list of HOA IDs for which user has active stickers
final userStickerIdsProvider = FutureProvider<List<String>>((ref) async {
  final activeStickers = await ref.watch(activeUserStickersProvider.future);
  return activeStickers.map((sticker) => sticker.hoaId).toList();
});


