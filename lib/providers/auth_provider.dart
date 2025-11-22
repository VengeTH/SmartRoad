import "package:flutter_riverpod/flutter_riverpod.dart";
import "../models/user_model.dart";
import "../services/auth_service.dart";

/// * Authentication state provider
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

/// * Authentication state
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// * Authentication notifier
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    _checkAuthStatus();
  }

  final AuthService _authService = AuthService.instance;

  /// * Check current authentication status
  Future<void> _checkAuthStatus() async {
    final String? userId = _authService.currentUserId;
    if (userId != null) {
      try {
        final UserModel user = await _authService.getUserProfile(userId);
        state = state.copyWith(user: user);
      } catch (e) {
        state = state.copyWith(error: e.toString());
      }
    }
  }

  /// * Sign up
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final UserModel user = await _authService.signUp(
        email: email,
        password: password,
        name: name,
      );
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// * Sign in
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final UserModel user = await _authService.signIn(
        email: email,
        password: password,
      );
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// * Sign out
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _authService.signOut();
      state = AuthState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// * Update profile
  Future<bool> updateProfile({
    String? name,
    String? profileImage,
  }) async {
    if (state.user == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final UserModel updatedUser = await _authService.updateProfile(
        userId: state.user!.id,
        name: name,
        profileImage: profileImage,
      );
      state = state.copyWith(user: updatedUser, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }
}

