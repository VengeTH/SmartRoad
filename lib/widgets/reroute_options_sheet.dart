import "package:flutter/material.dart";
import "../core/theme/app_theme.dart";
import "../models/saved_route.dart";
import "../services/routing_service.dart";
import "package:latlong2/latlong.dart";

/// * Bottom sheet showing reroute options when user deviates
class RerouteOptionsSheet extends StatelessWidget {
  final LatLng currentLocation;
  final LatLng destination;
  final VehicleType vehicleType;
  final SavedRoute? currentSavedRoute; // * The route user was following
  final List<SavedRoute> availableSavedRoutes; // * Routes user owns/bought
  final Function(RouteData) onSelectRoute;
  final Function()? onReturnToSavedRoute; // * Return to saved route if available
  
  const RerouteOptionsSheet({
    super.key,
    required this.currentLocation,
    required this.destination,
    required this.vehicleType,
    this.currentSavedRoute,
    this.availableSavedRoutes = const [],
    required this.onSelectRoute,
    this.onReturnToSavedRoute,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // * Header
          Row(
            children: [
              Icon(Icons.route, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Reroute Options",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          
          // * Return to saved route option
          if (onReturnToSavedRoute != null && currentSavedRoute != null)
            Card(
              color: AppTheme.primaryColor.withOpacity(0.1),
              child: ListTile(
                leading: Icon(Icons.bookmark, color: AppTheme.primaryColor),
                title: Text("Return to '${currentSavedRoute!.name}'"),
                subtitle: Text(
                  "Follow the original saved route",
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {
                  Navigator.pop(context);
                  onReturnToSavedRoute!();
                },
              ),
            ),
          
          if (onReturnToSavedRoute != null && currentSavedRoute != null)
            const SizedBox(height: 12),
          
          // * Available saved routes
          if (availableSavedRoutes.isNotEmpty) ...[
            const Text(
              "Your Saved Routes",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ...availableSavedRoutes.map((route) {
              if (route.id == currentSavedRoute?.id) return const SizedBox.shrink();
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    route.vehicleType.icon,
                    color: AppTheme.primaryColor,
                  ),
                  title: Text(route.name),
                  subtitle: Text(
                    "${route.distanceKm.toStringAsFixed(1)} km • ${route.duration.inMinutes} min",
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  trailing: route.priceCents > 0
                      ? Chip(
                          label: Text(route.formattedPrice),
                          backgroundColor: AppTheme.warningColor.withOpacity(0.2),
                        )
                      : const Icon(Icons.check_circle, color: Colors.green),
                  onTap: () {
                    // * TODO: Load route geometry and create RouteData
                    Navigator.pop(context);
                    // * onSelectRoute(routeData);
                  },
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
          
          // * Calculate new route option
          const Text(
            "New Routes",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.navigation, color: AppTheme.primaryColor),
              title: const Text("Calculate New Route"),
              subtitle: Text(
                "Find fastest route from current location",
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.pop(context, RerouteOption.calculateNew);
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum RerouteOption {
  returnToSaved,
  useSavedRoute,
  calculateNew,
}
