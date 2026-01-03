import "package:flutter/material.dart";
import "../core/theme/app_theme.dart";

/// * Dialog to choose route creation method
class RouteCreationDialog extends StatelessWidget {
  final VoidCallback onDrawRoute;
  final VoidCallback onUseNavigation;

  const RouteCreationDialog({
    super.key,
    required this.onDrawRoute,
    required this.onUseNavigation,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Create Route"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Choose how you want to create your route:",
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          // * Draw Route Option
          Card(
            elevation: 2,
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
                onDrawRoute();
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_location_alt,
                      size: 40,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Draw Route",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Manually draw your route on the map",
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // * Use Navigation Option
          Card(
            elevation: 2,
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
                onUseNavigation();
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.navigation,
                      size: 40,
                      color: AppTheme.secondaryColor,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Use Navigation",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Let the app calculate the best route",
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
