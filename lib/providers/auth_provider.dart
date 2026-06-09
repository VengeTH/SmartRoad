import "package:flutter_riverpod/flutter_riverpod.dart";
import "../services/supabase_service.dart";
import "../models/smartroad_user.dart";
import "../models/user_profile.dart";

/// * Demo user state (for demo mode)
final demoUserStateProvider = StateProvider<SmartRoadUser?>((ref) => null);

/// * Auth state provider
final authStateProvider = StreamProvider<SmartRoadUser?>((ref) {
  final service = SupabaseService();
  if (service.isDemoMode) {
    final demoUser = ref.watch(demoUserStateProvider);
    return Stream.value(demoUser);
  }
  // * Live mode: auth state is managed by the backend session
  // * For now, return null until backend auth is integrated
  return Stream.value(null);
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

