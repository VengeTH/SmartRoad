import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:geolocator/geolocator.dart";

/// * Location state provider
final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>(
  (ref) => LocationNotifier(),
);

/// * Location state
class LocationState {
  final Position? position;
  final bool isLoading;
  final String? error;
  final bool permissionGranted;

  LocationState({
    this.position,
    this.isLoading = false,
    this.error,
    this.permissionGranted = false,
  });

  LocationState copyWith({
    Position? position,
    bool? isLoading,
    String? error,
    bool? permissionGranted,
  }) {
    return LocationState(
      position: position ?? this.position,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      permissionGranted: permissionGranted ?? this.permissionGranted,
    );
  }
}

/// * Location notifier
class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier() : super(LocationState()) {
    requestPermission();
  }

  /// * Request location permission
  Future<void> requestPermission() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          isLoading: false,
          error: "Location services are disabled",
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            isLoading: false,
            error: "Location permissions are denied",
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          isLoading: false,
          error: "Location permissions are permanently denied",
        );
        return;
      }

      state = state.copyWith(permissionGranted: true);
      await getCurrentLocation();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// * Get current location
  Future<void> getCurrentLocation() async {
    if (!state.permissionGranted) {
      await requestPermission();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      state = state.copyWith(position: position, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// * Start listening to location updates
  void startLocationUpdates() {
    if (!state.permissionGranted) return;

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (Position position) {
        state = state.copyWith(position: position);
      },
      onError: (error) {
        state = state.copyWith(error: error.toString());
      },
    );
  }
}

