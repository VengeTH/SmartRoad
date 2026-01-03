import "package:flutter/material.dart";
import "../core/theme/app_theme.dart";
import "package:latlong2/latlong.dart";

/// * Dialog for creating a new route with options to draw or use navigation
class CreateRouteDialog extends StatelessWidget {
  final LatLng? currentLocation;
  
  const CreateRouteDialog({
    super.key,
    this.currentLocation,
  });
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Create Route"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Choose how you want to create your route:",
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 20),
          // * Draw Route Option
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context, CreateRouteOption.draw);
            },
            icon: const Icon(Icons.edit),
            label: const Text("Draw Route"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
            ),
          ),
          const SizedBox(height: 12),
          // * Use Navigation Option
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context, CreateRouteOption.navigation);
            },
            icon: const Icon(Icons.navigation),
            label: const Text("Use Navigation"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "• Draw Route: Manually draw your route on the map\n"
            "• Use Navigation: Search for destination and use calculated route",
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
      ],
    );
  }
}

enum CreateRouteOption {
  draw,
  navigation,
}
