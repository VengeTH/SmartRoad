import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:latlong2/latlong.dart";
import "../../models/saved_route.dart";
import "../../services/route_service.dart";
import "../../core/theme/app_theme.dart";
import "../../services/routing_service.dart";
import "../map/map_screen.dart";
import "../../widgets/route_card.dart";
import "../../widgets/create_route_dialog.dart";
import "../../providers/navigation_provider.dart";
import "../../providers/route_creation_provider.dart";
import "../../providers/auth_provider.dart";
import "../../widgets/route_activity_logs_sheet.dart";

/// * Routes screen - View, create, and manage saved routes
class RoutesScreen extends ConsumerStatefulWidget {
  const RoutesScreen({super.key});

  @override
  ConsumerState<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends ConsumerState<RoutesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final isGuest = user == null;

    if (isGuest) {
      return Scaffold(
        appBar: AppBar(title: const Text("Routes"), elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingXL),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.route_outlined,
                    size: 64,
                    color: AppTheme.textSecondary.withOpacity(0.6),
                  ),
                  const SizedBox(height: AppTheme.spacingLG),
                  Text(
                    "Sign in to create or save routes",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(
                    "Route creation and saving are disabled for guest accounts.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacingXL),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed("/login");
                      },
                      icon: const Icon(Icons.login),
                      label: const Text("Sign in"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final isDesktop = AppTheme.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Routes"),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_toggle_off),
            tooltip: "Search & Trip Logs",
            onPressed: () {
              RouteActivityLogsSheet.show(
                context,
                onSelectLog: (destination, mode, label) {
                  ref.read(navigationTabProvider.notifier).switchToMap();
                },
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.explore), text: "Discover"),
            Tab(icon: Icon(Icons.bookmark), text: "My Routes"),
            Tab(icon: Icon(Icons.trending_up), text: "Popular"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_DiscoverTab(), _MyRoutesTab(), _PopularRoutesTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "create_route_fab",
        onPressed: () async {
          // * Show route creation dialog first - this will block until user selects or cancels
          if (!mounted) return;

          final option = await showDialog<CreateRouteOption>(
            context: context,
            barrierDismissible: true,
            builder: (context) => const CreateRouteDialog(),
          );

          // * Only proceed if user selected an option (not cancelled)
          if (option == null || !mounted) return;

          // * Switch to Map tab
          ref.read(navigationTabProvider.notifier).switchToMap();

          // * Wait for MapScreen to be ready, then trigger the action
          await Future.delayed(const Duration(milliseconds: 500));

          if (mounted) {
            // * Trigger the appropriate action based on selection
            if (option == CreateRouteOption.draw) {
              ref.read(routeCreationTriggerProvider.notifier).state =
                  RouteCreationAction.startDrawing;
            } else if (option == CreateRouteOption.navigation) {
              ref.read(routeCreationTriggerProvider.notifier).state =
                  RouteCreationAction.useNavigation;
            }
          }
        },
        icon: const Icon(Icons.add),
        label: const Text("Create Route"),
      ),
    );
  }
}

/// * Discover tab - Find routes near you
class _DiscoverTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends ConsumerState<_DiscoverTab> {
  final RouteService _routeService = RouteService();
  List<SavedRoute> _discoveredRoutes = [];
  bool _isLoading = false;
  VehicleType? _selectedVehicle;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() => _isLoading = true);
    try {
      // * TODO: Get current location
      // * For now, use a default location (Manila)
      const defaultLocation = LatLng(14.5995, 120.9842);

      final routes = await _routeService.discoverRoutesNearby(
        location: defaultLocation,
        radiusMeters: 10000,
        vehicleType: _selectedVehicle,
        limit: 20,
      );

      setState(() {
        _discoveredRoutes = routes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading routes: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppTheme.isDesktop(context);
    final columns = isDesktop ? 2 : 1;
    final padding = AppTheme.responsivePadding(context);

    return Column(
      children: [
        // * Filter chips
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text("All Vehicles"),
                  selected: _selectedVehicle == null,
                  onSelected: (selected) {
                    setState(() => _selectedVehicle = null);
                    _loadRoutes();
                  },
                ),
                const SizedBox(width: 8),
                ...VehicleType.values.map((vehicle) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(vehicle.value),
                      selected: _selectedVehicle == vehicle,
                      onSelected: (selected) {
                        setState(() {
                          _selectedVehicle = selected ? vehicle : null;
                        });
                        _loadRoutes();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // * Routes list/grid
        Expanded(
          child:
              _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.brandAccentColor,
                      ),
                    )
                  : _discoveredRoutes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.explore_outlined,
                            size: 64,
                            color: AppTheme.textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No routes found nearby",
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Create a route to get started",
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRoutes,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: AppTheme.maxContentWidth(context),
                          ),
                          child: columns == 1
                              ? ListView.builder(
                                  padding: EdgeInsets.all(padding),
                                  itemCount: _discoveredRoutes.length,
                                  itemBuilder: (context, index) {
                                    final route = _discoveredRoutes[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: RouteCard(
                                        route: route,
                                        onTap: () =>
                                            _showRouteDetails(route),
                                        onUse: () => _useRoute(route),
                                        onPurchase:
                                            route.isFree
                                                ? null
                                                : () => _purchaseRoute(route),
                                      ),
                                    );
                                  },
                                )
                              : GridView.builder(
                                  padding: EdgeInsets.all(padding),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        crossAxisSpacing: AppTheme.spacingMD,
                                        mainAxisSpacing: AppTheme.spacingMD,
                                        childAspectRatio: 1.6,
                                      ),
                                  itemCount: _discoveredRoutes.length,
                                  itemBuilder: (context, index) {
                                    final route = _discoveredRoutes[index];
                                    return RouteCard(
                                      route: route,
                                      onTap: () => _showRouteDetails(route),
                                      onUse: () => _useRoute(route),
                                      onPurchase:
                                          route.isFree
                                              ? null
                                              : () => _purchaseRoute(route),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  void _showRouteDetails(SavedRoute route) {
    // * TODO: Show route details sheet
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(route.name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Distance: ${route.distanceKm.toStringAsFixed(2)} km"),
                Text("Duration: ${route.duration.inMinutes} min"),
                Text("Trust Score: ${route.trustScore.toStringAsFixed(1)}"),
                if (route.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children:
                        route.tags.entries
                            .where((e) => e.value == true)
                            .map(
                              (e) => Chip(
                                label: Text(e.key),
                                labelStyle: const TextStyle(fontSize: 12),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
              if (!route.isFree && route.isPurchased != true)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _purchaseRoute(route);
                  },
                  child: Text("Purchase (${route.formattedPrice})"),
                ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _useRoute(route);
                },
                child: const Text("Use Route"),
              ),
            ],
          ),
    );
  }

  void _useRoute(SavedRoute route) {
    // * Navigate to map - route will be loaded from Routes screen
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MapScreen()));
    // * TODO: Pass route to MapScreen to start navigation with saved route
  }

  Future<void> _purchaseRoute(SavedRoute route) async {
    try {
      await _routeService.purchaseRoute(route.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Route purchased successfully!")),
        );
        _loadRoutes(); // * Refresh to update purchase status
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error purchasing route: $e")));
      }
    }
  }
}

/// * My Routes tab - User's saved routes
class _MyRoutesTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MyRoutesTab> createState() => _MyRoutesTabState();
}

class _MyRoutesTabState extends ConsumerState<_MyRoutesTab> {
  List<SavedRoute> _myRoutes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMyRoutes();
  }

  Future<void> _loadMyRoutes() async {
    setState(() => _isLoading = true);
    try {
      // * TODO: Implement getMyRoutes in RouteService
      // * For now, return empty list
      setState(() {
        _myRoutes = [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppTheme.isDesktop(context);
    final columns = isDesktop ? 2 : 1;
    final padding = AppTheme.responsivePadding(context);

    return _isLoading
        ? Center(
            child: CircularProgressIndicator(color: AppTheme.brandAccentColor),
          )
        : _myRoutes.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bookmark_border,
                  size: 64,
                  color: AppTheme.textSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  "No saved routes yet",
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  "Create a route during navigation",
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 14),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadMyRoutes,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: AppTheme.maxContentWidth(context),
                ),
                child: columns == 1
                    ? ListView.builder(
                        padding: EdgeInsets.all(padding),
                        itemCount: _myRoutes.length,
                        itemBuilder: (context, index) {
                          final route = _myRoutes[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: RouteCard(
                              route: route,
                              onTap: () => _showRouteDetails(route),
                              onUse: () => _useRoute(route),
                              onEdit: () => _editRoute(route),
                              showEdit: true,
                            ),
                          );
                        },
                      )
                    : GridView.builder(
                        padding: EdgeInsets.all(padding),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: AppTheme.spacingMD,
                          mainAxisSpacing: AppTheme.spacingMD,
                          childAspectRatio: 1.6,
                        ),
                        itemCount: _myRoutes.length,
                        itemBuilder: (context, index) {
                          final route = _myRoutes[index];
                          return RouteCard(
                            route: route,
                            onTap: () => _showRouteDetails(route),
                            onUse: () => _useRoute(route),
                            onEdit: () => _editRoute(route),
                            showEdit: true,
                          );
                        },
                      ),
              ),
            ),
          );
  }

  void _showRouteDetails(SavedRoute route) {
    // * TODO: Show route details with edit options
  }

  void _useRoute(SavedRoute route) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MapScreen()));
    // * TODO: Pass route to MapScreen to start navigation with saved route
  }

  void _editRoute(SavedRoute route) {
    // * Set the route to edit in the provider
    ref.read(routeEditingProvider.notifier).state = route;

    // * Switch to Map tab
    ref.read(navigationTabProvider.notifier).switchToMap();

    // * Show message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Route loaded for editing. Switch to Map tab to adjust the path.",
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}

/// * Popular Routes tab - Most used routes
class _PopularRoutesTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PopularRoutesTab> createState() => _PopularRoutesTabState();
}

class _PopularRoutesTabState extends ConsumerState<_PopularRoutesTab> {
  final RouteService _routeService = RouteService();
  List<SavedRoute> _popularRoutes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPopularRoutes();
  }

  Future<void> _loadPopularRoutes() async {
    setState(() => _isLoading = true);
    try {
      const defaultLocation = LatLng(14.5995, 120.9842);
      final routes = await _routeService.discoverRoutesNearby(
        location: defaultLocation,
        radiusMeters: 50000,
        sortBy: 'usage_count',
        limit: 20,
      );
      setState(() {
        _popularRoutes = routes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppTheme.isDesktop(context);
    final columns = isDesktop ? 2 : 1;
    final padding = AppTheme.responsivePadding(context);

    return _isLoading
        ? Center(
            child: CircularProgressIndicator(color: AppTheme.brandAccentColor),
          )
        : _popularRoutes.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.trending_up,
                  size: 64,
                  color: AppTheme.textSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  "No popular routes yet",
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadPopularRoutes,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: AppTheme.maxContentWidth(context),
                ),
                child: columns == 1
                    ? ListView.builder(
                        padding: EdgeInsets.all(padding),
                        itemCount: _popularRoutes.length,
                        itemBuilder: (context, index) {
                          final route = _popularRoutes[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: RouteCard(
                              route: route,
                              onTap: () => _showRouteDetails(route),
                              onUse: () => _useRoute(route),
                              onPurchase:
                                  route.isFree ? null : () => _purchaseRoute(route),
                            ),
                          );
                        },
                      )
                    : GridView.builder(
                        padding: EdgeInsets.all(padding),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: AppTheme.spacingMD,
                          mainAxisSpacing: AppTheme.spacingMD,
                          childAspectRatio: 1.6,
                        ),
                        itemCount: _popularRoutes.length,
                        itemBuilder: (context, index) {
                          final route = _popularRoutes[index];
                          return RouteCard(
                            route: route,
                            onTap: () => _showRouteDetails(route),
                            onUse: () => _useRoute(route),
                            onPurchase:
                                route.isFree ? null : () => _purchaseRoute(route),
                          );
                        },
                      ),
              ),
            ),
          );
  }

  void _showRouteDetails(SavedRoute route) {
    // * TODO: Show route details
  }

  void _useRoute(SavedRoute route) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MapScreen()));
    // * TODO: Pass route to MapScreen to start navigation with saved route
  }

  Future<void> _purchaseRoute(SavedRoute route) async {
    try {
      await _routeService.purchaseRoute(route.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Route purchased!")));
        _loadPopularRoutes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}
