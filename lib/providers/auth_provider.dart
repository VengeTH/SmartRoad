import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../services/supabase_service.dart";
import "../models/user_profile.dart";

/// * Demo user state (for demo mode)
final demoUserStateProvider = StateProvider<User?>((ref) => null);

/// * Auth state provider
final authStateProvider = StreamProvider<User?>((ref) {
  final service = SupabaseService();
  if (service.isDemoMode) {
    // * In demo mode, watch the demo user state
    final demoUser = ref.watch(demoUserStateProvider);
    return Stream.value(demoUser);
  }
  final client = service.client;
  if (client == null) {
    return Stream.value(null);
  }
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

