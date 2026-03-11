import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:geolocator/geolocator.dart";

import "../../core/theme/app_theme.dart";
import "../../models/fuel_station.dart";
import "../../models/fuel_type.dart";
import "../../providers/fuel_provider.dart";
import "../../providers/location_provider.dart";
import "../../providers/navigation_provider.dart";
import "../../screens/commute/commute_mode_screen.dart";
import "../../utils/fuel_utils.dart";
import "../../widgets/fuel_station_detail_sheet.dart";

/// * Sort options for the fuel stations list.
enum FuelSortOption {
  distance,
  price,
  location,
  lastUpdated,
}

/// * Radius options in km for "stations within X km".
const List<double> _radiusOptionsKm = [5.0, 10.0, 25.0];

/// * Fuel Prices screen: list of stations within radius, sortable by price,
/// * distance, location name, or last updated.
class FuelPricesScreen extends ConsumerStatefulWidget {
  const FuelPricesScreen({super.key});

  @override
  ConsumerState<FuelPricesScreen> createState() => _FuelPricesScreenState();
}

class _FuelPricesScreenState extends ConsumerState<FuelPricesScreen> {
  int _radiusIndex = 1; // 10 km default
  FuelSortOption _sortOption = FuelSortOption.distance;
  FuelType _priceSortFuelType = FuelType.unleaded91;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadIfHasLocation());
  }

  Future<void> _loadIfHasLocation() async {
    final pos = await ref.read(currentLocationProvider.future);
    if (!mounted) return;
    if (pos != null) {
      final radiusKm = _radiusOptionsKm[_radiusIndex];
      ref.read(nearbyFuelStationsProvider.notifier).load(
        lat: pos.latitude,
        lon: pos.longitude,
        radiusKm: radiusKm,
      );
    } else {
      ref.read(nearbyFuelStationsProvider.notifier).clear();
    }
  }

  void _onRadiusChanged(int index) {
    setState(() => _radiusIndex = index);
    _loadIfHasLocation();
  }

  List<FuelStation> _sortedStations(
    List<FuelStation> stations,
    Position? position,
  ) {
    final list = List<FuelStation>.from(stations);
    final lat = position?.latitude;
    final lon = position?.longitude;

    switch (_sortOption) {
      case FuelSortOption.distance:
        if (lat != null && lon != null) {
          list.sort((a, b) {
            final da = FuelUtils.calculateDistance(lat, lon, a.latitude, a.longitude);
            final db = FuelUtils.calculateDistance(lat, lon, b.latitude, b.longitude);
            return da.compareTo(db);
          });
        } else {
          list.sort((a, b) => a.name.compareTo(b.name));
        }
        break;
      case FuelSortOption.price:
        list.sort((a, b) {
          final pa = _priceForType(a, _priceSortFuelType);
          final pb = _priceForType(b, _priceSortFuelType);
          if (pa == null && pb == null) return a.name.compareTo(b.name);
          if (pa == null) return 1;
          if (pb == null) return -1;
          return pa.compareTo(pb);
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

  double? _priceForType(FuelStation s, FuelType type) {
    final p = s.prices.where((e) => e.fuelType == type).firstOrNull;
    return p?.price;
  }

  DateTime _latestUpdate(FuelStation s) {
    if (s.prices.isEmpty) return DateTime(0);
    return s.prices.map((e) => e.updatedAt).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  void _showStationSheet(FuelStation station) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => FuelStationDetailSheet(
        station: station,
        onClose: () => Navigator.of(ctx).pop(),
        onGetDirections: () {
          Navigator.of(ctx).pop();
          ref.read(selectedFuelStationProvider.notifier).selectStationDirect(station);
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
          _loadIfHasLocation();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locationAsync = ref.watch(currentLocationProvider);
    final stationsAsync = ref.watch(nearbyFuelStationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Fuel Prices"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadIfHasLocation(),
            tooltip: "Refresh",
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // * Radius selector
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spacingMD, AppTheme.spacingSM, AppTheme.spacingMD, 0),
            child: Wrap(
              spacing: AppTheme.spacingSM,
              children: List.generate(_radiusOptionsKm.length, (i) {
                final km = _radiusOptionsKm[i];
                final selected = _radiusIndex == i;
                return FilterChip(
                  label: Text("${km.toInt()} km"),
                  selected: selected,
                  onSelected: (_) => _onRadiusChanged(i),
                );
              }),
            ),
          ),
          // * Sort selector
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spacingMD, AppTheme.spacingSM, AppTheme.spacingMD, 0),
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
                        _sortChip(theme, FuelSortOption.location, "Location (A–Z)"),
                        _sortChip(theme, FuelSortOption.lastUpdated, "Last updated"),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_sortOption == FuelSortOption.price) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.spacingMD, AppTheme.spacingXS, AppTheme.spacingMD, 0),
              child: Wrap(
                spacing: AppTheme.spacingXS,
                children: FuelType.values.map((ft) {
                  final selected = _priceSortFuelType == ft;
                  return ChoiceChip(
                    label: Text(ft.shortLabel),
                    selected: selected,
                    onSelected: (_) => setState(() => _priceSortFuelType = ft),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spacingSM),
          // * List
          Expanded(
            child: locationAsync.when(
              data: (position) {
                if (position == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingXL),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_off, size: 48, color: theme.colorScheme.outline),
                          const SizedBox(height: AppTheme.spacingMD),
                          Text(
                            "Enable location to see nearby stations",
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return stationsAsync.when(
                  data: (stations) {
                    final sorted = _sortedStations(stations, position);
                    if (sorted.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingXL),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_gas_station_outlined, size: 48, color: theme.colorScheme.outline),
                              const SizedBox(height: AppTheme.spacingMD),
                              Text(
                                "No stations in this radius",
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge,
                              ),
                              const SizedBox(height: AppTheme.spacingSM),
                              Text(
                                "Try a larger radius or enable location.",
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () => _loadIfHasLocation(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD, vertical: AppTheme.spacingSM),
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
                            distanceKm: distM / 1000.0,
                            onTap: () => _showStationSheet(station),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingXL),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                          const SizedBox(height: AppTheme.spacingMD),
                          Text(
                            "Something went wrong",
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: AppTheme.spacingSM),
                          ElevatedButton(
                            onPressed: () => _loadIfHasLocation(),
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingXL),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_off, size: 48, color: theme.colorScheme.outline),
                      const SizedBox(height: AppTheme.spacingMD),
                      const Text("Location unavailable"),
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
  final double distanceKm;
  final VoidCallback onTap;

  const _StationCard({
    required this.station,
    required this.distanceKm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  Icon(Icons.local_gas_station, color: theme.colorScheme.primary, size: 24),
                  const SizedBox(width: AppTheme.spacingSM),
                  Expanded(
                    child: Text(
                      station.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    "${distanceKm.toStringAsFixed(1)} km",
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "${station.city}, ${station.province}",
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              if (station.prices.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingSM),
                Wrap(
                  spacing: AppTheme.spacingSM,
                  runSpacing: 4,
                  children: station.prices.map((p) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
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
}
