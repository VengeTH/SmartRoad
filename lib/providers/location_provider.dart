import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:geolocator/geolocator.dart";
import "../services/location_service.dart";

/// * Current location provider (one-shot, used by screens that need a quick initial position).
/// * For continuous location updates, use Geolocator.getPositionStream() directly.
final currentLocationProvider = FutureProvider<Position?>((ref) async {
  final locationService = LocationService();
  return await locationService.getCurrentPosition();
});

/// * Location permission provider
final locationPermissionProvider = FutureProvider<bool>((ref) async {
  final locationService = LocationService();
  return await locationService.isPermissionGranted();
});
