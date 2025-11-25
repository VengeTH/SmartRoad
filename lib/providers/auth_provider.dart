import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";
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
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return await SupabaseService().getProfile(userId);
});

