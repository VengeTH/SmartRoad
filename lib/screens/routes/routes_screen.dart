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

Future<void> _startRouteCreationFlow({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final option = await showDialog<CreateRouteOption>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (context) => const CreateRouteDialog(),
  );

  if (option == null || !context.mounted) return;

  // * Switch to Map tab
  ref.read(navigationTabProvider.notifier).switchToMap();

  // * Wait for MapScreen to be ready, then trigger the action
  await Future.delayed(const Duration(milliseconds: 500));
  if (!context.mounted) return;

  // * Trigger the appropriate action based on selection
  if (option == CreateRouteOption.draw) {
    ref.read(routeCreationTriggerProvider.notifier).state =
        RouteCreationAction.startDrawing;
    return;
  }

  if (option == CreateRouteOption.navigation) {
    ref.read(routeCreationTriggerProvider.notifier).state =
        RouteCreationAction.useNavigation;
  }
}

/// * Routes screen - View, create, and manage saved routes
class RoutesScreen extends ConsumerStatefulWidget {
  const RoutesScreen({super.key});
  
  @override
  ConsumerState<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends ConsumerState<RoutesScreen> with SingleTickerProviderStateMixin {
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
        appBar: AppBar(
          title: const Text("Routes"),
          elevation: 0,
        ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Routes"),
        elevation: 0,
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
        children: [
          _DiscoverTab(),
          _MyRoutesTab(),
          _PopularRoutesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "create_route_fab",
        onPressed: () => _startRouteCreationFlow(context: context, ref: ref),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading routes: $e")),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // * Filter chips
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withOpacity(0.65),
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(
              color: AppTheme.borderColor.withOpacity(0.9),
              width: 1,
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text("All Vehicles"),
                  selected: _selectedVehicle == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedVehicle = null;
                    });
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
        // * Routes list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _discoveredRoutes.isEmpty
                  ? Center(
                      child: _RoutesEmptyState(
                        icon: Icons.explore_outlined,
                        title: "No routes found nearby",
                        subtitle: "Create a route to get started.",
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRoutes,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _discoveredRoutes.length,
                        itemBuilder: (context, index) {
                          final route = _discoveredRoutes[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: RouteCard(
                              route: route,
                              onTap: () => _showRouteDetails(route),
                              onUse: () => _useRoute(route),
                              onPurchase: route.isFree ? null : () => _purchaseRoute(route),
                            ),
                          );
                        },
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
      builder: (context) => AlertDialog(
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
                children: route.tags.entries
                    .where((e) => e.value == true)
                    .map((e) => Chip(
                          label: Text(e.key),
                          labelStyle: const TextStyle(fontSize: 12),
                        ))
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MapScreen(),
      ),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error purchasing route: $e")),
        );
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
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _myRoutes.isEmpty
            ? Center(
                child: _RoutesEmptyState(
                  icon: Icons.bookmark_border,
                  title: "No saved routes yet",
                  subtitle:
                      "Create a route during navigation, then save it here for quick access.",
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadMyRoutes,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
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
                ),
              );
  }
  
  void _showRouteDetails(SavedRoute route) {
    // * TODO: Show route details with edit options
  }
  
  void _useRoute(SavedRoute route) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MapScreen(),
      ),
    );
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
          content: Text("Route loaded for editing. Switch to Map tab to adjust the path."),
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
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _popularRoutes.isEmpty
            ? const Center(
                child: _RoutesEmptyState(
                  icon: Icons.trending_up_rounded,
                  title: "No popular routes yet",
                  subtitle:
                      "As the community uses and shares routes, you'll see trending routes here.",
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadPopularRoutes,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _popularRoutes.length,
                  itemBuilder: (context, index) {
                    final route = _popularRoutes[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RouteCard(
                        route: route,
                        onTap: () => _showRouteDetails(route),
                        onUse: () => _useRoute(route),
                        onPurchase: route.isFree ? null : () => _purchaseRoute(route),
                      ),
                    );
                  },
                ),
              );
  }
  
  void _showRouteDetails(SavedRoute route) {
    // * TODO: Show route details
  }
  
  void _useRoute(SavedRoute route) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MapScreen(),
      ),
    );
    // * TODO: Pass route to MapScreen to start navigation with saved route
  }
  
  Future<void> _purchaseRoute(SavedRoute route) async {
    try {
      await _routeService.purchaseRoute(route.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Route purchased!")),
        );
        _loadPopularRoutes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }
}

class _RoutesEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _RoutesEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withOpacity(0.75),
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            border: Border.all(
              color: AppTheme.borderColor.withOpacity(0.9),
              width: 1,
            ),
            boxShadow: AppTheme.shadowMedium,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(height: AppTheme.spacingLG),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
