import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:geolocator/geolocator.dart";

import "../../core/theme/app_theme.dart";
import "../../models/fuel_station.dart";
import "../../models/fuel_type.dart";
import "../../providers/fuel_provider.dart";
import "../../providers/navigation_provider.dart";
import "../../screens/commute/commute_mode_screen.dart";
import "../../services/location_service.dart";
import "../../services/location_search_service.dart";
import "../../utils/fuel_utils.dart";
import "../../widgets/fuel_station_detail_sheet.dart";

/// * Sort options for the fuel stations list.
enum FuelSortOption { distance, price, location, lastUpdated }

/// * Fuel Prices screen: list of stations within custom radius, sortable by price,
/// * distance, location name, or last updated.
class FuelPricesScreen extends ConsumerStatefulWidget {
  const FuelPricesScreen({super.key});

  @override
  ConsumerState<FuelPricesScreen> createState() => _FuelPricesScreenState();
}

class _FuelPricesScreenState extends ConsumerState<FuelPricesScreen> {
  double _radiusKm = 25.0;
  FuelSortOption _sortOption = FuelSortOption.distance;
  FuelType _priceSortFuelType = FuelType.unleaded91;

  Position? _currentPosition;
  bool _isLoadingLocation = true;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _radiusDebounce;
  bool _isRetryingLocation = false;
  Position? _lastLoadedPosition;
  DateTime? _lastLoadedAt;
  final Map<String, String> _addressOverrides = {};
  final Set<String> _addressLookupsInFlight = {};
  final Map<String, DateTime> _addressRetryNotBefore = {};
  final LocationSearchService _locationSearchService = LocationSearchService();

  @override
  void initState() {
    super.initState();
    _startLocationStream();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _radiusDebounce?.cancel();
    super.dispose();
  }

  /// * Get location directly from Geolocator stream (same as map screen).
  void _startLocationStream() {
    // * Listen immediately so web can deliver the first fix as soon as available.
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 50, // * Only update on significant movement (50m)
      ),
    ).listen(
      (position) {
        if (!mounted) return;
        final hadPosition = _currentPosition != null;
        final shouldReload = _shouldReloadForPositionUpdate(
          position,
          hadPosition,
        );
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });
        // * Reload on first acquisition, significant movement, or when current list is empty.
        if (shouldReload) {
          _loadStations();
        }
      },
      onError: (e) {
        debugPrint("[FuelPricesScreen] Position stream error: $e");
      },
    );

    // * Do first provider-touching load after first frame to avoid Riverpod lifecycle error.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _getInitialPosition();
    });
  }

  Future<void> _getInitialPosition() async {
    final locationService = LocationService();

    final memoryCached = locationService.memoryCachedPosition;
    if (memoryCached != null && mounted) {
      setState(() {
        _currentPosition = memoryCached;
        _isLoadingLocation = false;
        _isRetryingLocation = false;
      });
      _loadStations();
      return;
    }

    if (mounted && _currentPosition == null) {
      setState(() {
        _isLoadingLocation = true;
        _isRetryingLocation = false;
      });
    }

    // * Try cached position first for instant display
    if (!kIsWeb) {
      try {
        final cached = await locationService.getLastKnownPosition();
        if (cached != null && mounted) {
          setState(() {
            _currentPosition = cached;
            _isLoadingLocation = false;
            _isRetryingLocation = false;
          });
          _loadStations();
          return;
        }
      } catch (_) {}
    }

    // * Match the map screen: get a fast first fix, then refine in background.
    try {
      final pos = await locationService.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
        preferCached: true,
      );
      if (!mounted) return;
      if (pos != null) {
        setState(() {
          _currentPosition = pos;
          _isLoadingLocation = false;
          _isRetryingLocation = false;
        });
        _loadStations();

        unawaited(_refinePositionInBackground(locationService));
      } else {
        unawaited(_retryPositionLookup(locationService));
      }
    } catch (e) {
      debugPrint("[FuelPricesScreen] Error getting position: $e");
      unawaited(_retryPositionLookup(locationService));
    }
  }

  Future<void> _refinePositionInBackground(
    LocationService locationService,
  ) async {
    try {
      final precise = await locationService.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
        preferCached: false,
      );
      if (!mounted || precise == null) return;

      final current = _currentPosition;
      if (current != null) {
        final movedMeters = FuelUtils.calculateDistance(
          current.latitude,
          current.longitude,
          precise.latitude,
          precise.longitude,
        );
        if (movedMeters < 0.008) {
          return;
        }
      }

      setState(() {
        _currentPosition = precise;
        _isLoadingLocation = false;
        _isRetryingLocation = false;
      });
      _loadStations();
    } catch (_) {}
  }

  Future<void> _retryPositionLookup(LocationService locationService) async {
    if (_currentPosition != null) return;
    if (mounted) {
      setState(() {
        _isRetryingLocation = true;
        _isLoadingLocation = true;
      });
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted || _currentPosition != null) return;

    try {
      final retry = await locationService.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
        preferCached: true,
      );
      if (!mounted) return;
      if (retry == null) {
        setState(() {
          _isLoadingLocation = false;
          _isRetryingLocation = false;
        });
        return;
      }

      setState(() {
        _currentPosition = retry;
        _isLoadingLocation = false;
        _isRetryingLocation = false;
      });
      _loadStations();
    } catch (_) {
      if (!mounted || _currentPosition != null) return;
      setState(() {
        _isLoadingLocation = false;
        _isRetryingLocation = false;
      });
    }
  }

  void _loadStations() {
    final pos = _currentPosition;
    if (pos == null) return;

    _lastLoadedPosition = pos;
    _lastLoadedAt = DateTime.now();

    // * Defer provider state mutation out of potential widget lifecycle/build stack.
    Future<void>(() {
      if (!mounted) return;
      ref
          .read(nearbyFuelStationsProvider.notifier)
          .load(lat: pos.latitude, lon: pos.longitude, radiusKm: _radiusKm);
    });
  }

  bool _shouldReloadForPositionUpdate(Position nextPosition, bool hadPosition) {
    if (!hadPosition) return true;

    if (_lastLoadedAt == null) return true;

    final stations = ref.read(nearbyFuelStationsProvider).valueOrNull;
    if (stations != null && stations.isEmpty) {
      return true;
    }

    final last = _lastLoadedPosition;
    if (last == null) return true;

    final movedKm = FuelUtils.calculateDistance(
      last.latitude,
      last.longitude,
      nextPosition.latitude,
      nextPosition.longitude,
    );
    if (movedKm < 0.20) return false;

    final lastAt = _lastLoadedAt;
    if (lastAt != null && DateTime.now().difference(lastAt).inSeconds < 4) {
      return false;
    }

    return true;
  }

  void _prefetchMissingAddresses(List<FuelStation> stations) {
    final now = DateTime.now();
    final toLookup =
        stations
            .where((s) {
              final retryAt = _addressRetryNotBefore[s.id];
              if (retryAt != null && now.isBefore(retryAt)) {
                return false;
              }

              final rawAddress = s.addressLine?.trim() ?? '';
              final overridden = _addressOverrides[s.id]?.trim() ?? '';
              final effective = overridden.isNotEmpty ? overridden : rawAddress;

              final hasAddress = effective.isNotEmpty;
              final weakAddress = _isWeakAddress(effective, s.name);

              if (!hasAddress) return true;
              if (weakAddress) return true;
              return false;
            })
            .take(5)
            .toList();

    for (final station in toLookup) {
      if (_addressLookupsInFlight.contains(station.id)) continue;
      _addressLookupsInFlight.add(station.id);

      unawaited(() async {
        try {
          final structured = await _locationSearchService
              .getStructuredAddressFromCoordinates(
                station.latitude,
                station.longitude,
              )
              .timeout(const Duration(seconds: 4));
          if (!mounted) return;
          if (structured != null && structured.isNotEmpty) {
            setState(() {
              _addressOverrides[station.id] = structured;
              _addressRetryNotBefore.remove(station.id);
            });
          }
        } catch (_) {
          _addressRetryNotBefore[station.id] = DateTime.now().add(
            const Duration(seconds: 45),
          );
        } finally {
          _addressLookupsInFlight.remove(station.id);
        }
      }());
    }
  }

  bool _isWeakAddress(String address, String stationName) {
    if (address.isEmpty) return true;

    final clean = address.trim().toLowerCase();
    final station = stationName.trim().toLowerCase();
    if (clean == station) return true;

    final parts =
        clean
            .split(',')
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();
    // Accept any address with at least 2 meaningful parts (e.g. "Barangay, City")
    return parts.length < 2;
  }



  void _onRadiusChanged(double newRadius) {
    setState(() => _radiusKm = newRadius);
    // * Debounce to avoid spamming load on every slider pixel
    _radiusDebounce?.cancel();
    _radiusDebounce = Timer(const Duration(milliseconds: 300), () {
      _loadStations();
    });
  }

  List<FuelStation> _sortedStations(
    List<FuelStation> stations,
    Position position,
  ) {
    final list = List<FuelStation>.from(stations);
    final lat = position.latitude;
    final lon = position.longitude;

    switch (_sortOption) {
      case FuelSortOption.distance:
        list.sort((a, b) {
          final da = FuelUtils.calculateDistance(
            lat,
            lon,
            a.latitude,
            a.longitude,
          );
          final db = FuelUtils.calculateDistance(
            lat,
            lon,
            b.latitude,
            b.longitude,
          );
          return da.compareTo(db);
        });
        break;
      case FuelSortOption.price:
        list.sort((a, b) {
          final pa = _priceForType(a, _priceSortFuelType);
          final pb = _priceForType(b, _priceSortFuelType);
          if (pa == null && pb == null) {
            return _compareByDistanceThenName(a, b, lat, lon);
          }
          if (pa == null) return 1;
          if (pb == null) return -1;
          final priceCompare = pa.compareTo(pb);
          if (priceCompare != 0) return priceCompare;
          return _compareByDistanceThenName(a, b, lat, lon);
        });
        break;
      case FuelSortOption.location:
        list.sort((a, b) {
          final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          if (c != 0) return c;
          return a.city.compareTo(b.city);
        });
        break;
      case FuelSortOption.lastUpdated:
        list.sort((a, b) {
          final ta = _latestUpdate(a);
          final tb = _latestUpdate(b);
          return tb.compareTo(ta); // newest first
        });
        break;
    }
    return list;
  }

  int _compareByDistanceThenName(
    FuelStation a,
    FuelStation b,
    double lat,
    double lon,
  ) {
    final da = FuelUtils.calculateDistance(lat, lon, a.latitude, a.longitude);
    final db = FuelUtils.calculateDistance(lat, lon, b.latitude, b.longitude);
    final distanceCompare = da.compareTo(db);
    if (distanceCompare != 0) return distanceCompare;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  double? _priceForType(FuelStation s, FuelType type) {
    final p = s.prices.where((e) => e.fuelType == type).firstOrNull;
    return p?.price;
  }

  DateTime _latestUpdate(FuelStation s) {
    if (s.prices.isEmpty) return DateTime(0);
    return s.prices
        .map((e) => e.updatedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  void _showStationSheet(FuelStation station) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => FuelStationDetailSheet(
            station: station,
            onClose: () => Navigator.of(ctx).pop(),
            onGetDirections: () {
              Navigator.of(ctx).pop();
              ref
                  .read(selectedFuelStationProvider.notifier)
                  .selectStationDirect(station);
              ref.read(navigationTabProvider.notifier).switchToMap();
            },
            onCommuteToLocation: () {
              Navigator.of(ctx).pop();
              Navigator.of(ctx).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CommuteModeScreen(),
                  settings: RouteSettings(
                    arguments: <String, dynamic>{
                      "destinationName": station.name,
                      "lat": station.latitude,
                      "lon": station.longitude,
                    },
                  ),
                ),
              );
            },
            onUpdatePrices: () {
              ref.read(selectedFuelStationProvider.notifier).refresh();
              _loadStations();
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stationsAsync = ref.watch(nearbyFuelStationsProvider);
    final position = _currentPosition;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Fuel Prices"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _getInitialPosition();
            },
            tooltip: "Refresh",
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // * Radius slider (1-100 km)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingMD,
              AppTheme.spacingSM,
              AppTheme.spacingMD,
              AppTheme.spacingSM,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Radius: ${_radiusKm.toStringAsFixed(0)} km",
                  style: theme.textTheme.bodyMedium,
                ),
                Slider(
                  value: _radiusKm,
                  min: 1,
                  max: 100,
                  divisions: 99,
                  label: "${_radiusKm.toStringAsFixed(0)} km",
                  onChanged: _onRadiusChanged,
                ),
              ],
            ),
          ),
          // * Sort selector
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingMD,
              AppTheme.spacingSM,
              AppTheme.spacingMD,
              0,
            ),
            child: Row(
              children: [
                Text("Sort: ", style: theme.textTheme.bodyMedium),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _sortChip(theme, FuelSortOption.distance, "Distance"),
                        _sortChip(theme, FuelSortOption.price, "Price"),
                        _sortChip(
                          theme,
                          FuelSortOption.location,
                          "Location (A–Z)",
                        ),
                        _sortChip(
                          theme,
                          FuelSortOption.lastUpdated,
                          "Last updated",
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_sortOption == FuelSortOption.price) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingMD,
                AppTheme.spacingXS,
                AppTheme.spacingMD,
                0,
              ),
              child: Wrap(
                spacing: AppTheme.spacingXS,
                children:
                    FuelType.values.map((ft) {
                      final selected = _priceSortFuelType == ft;
                      return ChoiceChip(
                        label: Text(ft.shortLabel),
                        selected: selected,
                        onSelected:
                            (_) => setState(() => _priceSortFuelType = ft),
                      );
                    }).toList(),
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spacingSM),
          // * List
          Expanded(
            child:
                (position == null &&
                        (_isLoadingLocation || _isRetryingLocation))
                    ? const Center(child: CircularProgressIndicator())
                    : position == null
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingXL),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_off,
                              size: 48,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: AppTheme.spacingMD),
                            Text(
                              "Unable to get location",
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: AppTheme.spacingSM),
                            Text(
                              "Check that location is enabled and try refreshing.",
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingMD),
                            ElevatedButton(
                              onPressed: _getInitialPosition,
                              child: const Text("Refresh"),
                            ),
                          ],
                        ),
                      ),
                    )
                    : stationsAsync.when(
                      data: (stations) {
                        final sorted = _sortedStations(stations, position);
                        _prefetchMissingAddresses(sorted);
                        if (sorted.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spacingXL),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_gas_station_outlined,
                                    size: 48,
                                    color: theme.colorScheme.outline,
                                  ),
                                  const SizedBox(height: AppTheme.spacingMD),
                                  Text(
                                    "No stations in this radius",
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: AppTheme.spacingSM),
                                  Text(
                                    "Try a larger radius.",
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return RefreshIndicator(
                          onRefresh: () async => _getInitialPosition(),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingMD,
                              vertical: AppTheme.spacingSM,
                            ),
                            itemCount: sorted.length,
                            itemBuilder: (context, index) {
                              final station = sorted[index];
                              final distM = FuelUtils.calculateDistance(
                                position.latitude,
                                position.longitude,
                                station.latitude,
                                station.longitude,
                              );
                              return _StationCard(
                                station: station,
                                addressOverride: _addressOverrides[station.id],
                                distanceKm: distM / 1000.0,
                                onTap: () => _showStationSheet(station),
                              );
                            },
                          ),
                        );
                      },
                      loading:
                          () =>
                              const Center(child: CircularProgressIndicator()),
                      error:
                          (err, _) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spacingXL),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: theme.colorScheme.error,
                                  ),
                                  const SizedBox(height: AppTheme.spacingMD),
                                  Text(
                                    "Something went wrong",
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: AppTheme.spacingSM),
                                  ElevatedButton(
                                    onPressed: _getInitialPosition,
                                    child: const Text("Retry"),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _sortChip(ThemeData theme, FuelSortOption option, String label) {
    final selected = _sortOption == option;
    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.spacingXS),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _sortOption = option),
      ),
    );
  }
}

/// * Single station card for the list.
class _StationCard extends StatelessWidget {
  final FuelStation station;
  final String? addressOverride;
  final double distanceKm;
  final VoidCallback onTap;

  const _StationCard({
    required this.station,
    this.addressOverride,
    required this.distanceKm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locationLabel = _buildLocationLabel();
    final distanceLabel = _buildDistanceLabel();

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_gas_station,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  Expanded(
                    child: Text(
                      station.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    distanceLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              if (locationLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  locationLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
              if (station.prices.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingSM),
                Wrap(
                  spacing: AppTheme.spacingSM,
                  runSpacing: 4,
                  children:
                      station.prices.map((p) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSM,
                            ),
                          ),
                          child: Text(
                            "${p.fuelType.shortLabel}: ${FuelUtils.formatPrice(p.price)}",
                            style: theme.textTheme.bodySmall,
                          ),
                        );
                      }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _buildLocationLabel() {
    final addressLine = (addressOverride ?? station.addressLine)?.trim();
    if (addressLine != null && addressLine.isNotEmpty) {
      return addressLine;
    }

    final parts = <String>[];
    final city = station.city.trim();
    final province = station.province.trim();

    if (city.isNotEmpty) {
      parts.add(city);
    }
    if (province.isNotEmpty && province.toLowerCase() != city.toLowerCase()) {
      parts.add(province);
    }

    if (parts.isNotEmpty) {
      return parts.join(', ');
    }

    return 'Address unavailable';
  }

  String _buildDistanceLabel() {
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }
}
