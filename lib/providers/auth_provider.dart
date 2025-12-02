import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:flutter/foundation.dart";
import "../services/supabase_service.dart";
import "../models/user_profile.dart";
import "dart:async";

/// * Auth state provider
final authStateProvider = StreamProvider<User?>((ref) {
  final service = SupabaseService();
  
  // * ALWAYS check demo mode first - never access Supabase if in demo mode
  if (service.isDemoMode) {
    return Stream.value(service.currentUser);
  }
  
  // * Get client - it will return null if not initialized
  final client = service.client;
  if (client == null) {
    // * Supabase not initialized, return null (user not logged in)
    return Stream.value(null);
  }
  
  // * Only access Supabase auth if we have a valid client
  return client.auth.onAuthStateChange.map((event) => event.session?.user);
});

/// * Current user ID provider
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull?.id;
});

/// * User profile provider
final userProfileProvider = FutureProvider.family<UserProfile?, String?>((ref, userId) async {
  if (userId == null) return null;
  return await SupabaseService().getProfile(userId);
});

/// * Current user profile provider
final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  try {
    final userId = ref.watch(currentUserIdProvider);
    debugPrint("🔍 [ProfileProvider] UserId: $userId");
    
    if (userId == null) {
      debugPrint("⚠️ [ProfileProvider] UserId is null");
      return null;
    }
    
    final service = SupabaseService();
    debugPrint("🔍 [ProfileProvider] Demo mode: ${service.isDemoMode}");
    
    final profile = await service.getProfile(userId);
    debugPrint("🔍 [ProfileProvider] Profile: ${profile?.name ?? 'null'}");
    
    return profile;
  } catch (e, stack) {
    debugPrint("❌ [ProfileProvider] Error: $e");
    debugPrint("❌ [ProfileProvider] Stack: $stack");
    // * Don't rethrow - return null instead so UI can handle it gracefully
    return null;
  }
});

