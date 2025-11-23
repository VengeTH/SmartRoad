import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../services/supabase_service.dart";
import "../models/user_profile.dart";

/// * Auth state provider
final authStateProvider = StreamProvider<User?>((ref) {
  return SupabaseService().client.auth.onAuthStateChange.map((event) => event.session?.user);
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

