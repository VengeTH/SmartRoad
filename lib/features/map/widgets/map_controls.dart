/// * Reusable Map Control Widgets for MapLibre map
import "package:flutter/material.dart";
import "../../../core/theme/app_theme.dart";

/// * A compact floating action button for map controls
class MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool isActive;
  final Color? activeColor;

  const MapControlButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.isActive = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? (activeColor ?? AppTheme.primaryColor)
        : AppTheme.surfaceColor;
    final iconColor = isActive ? Colors.white : AppTheme.textPrimary;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor, size: 22),
        onPressed: onTap,
        tooltip: tooltip,
        splashRadius: 22,
      ),
    );
  }
}

/// * Column of map control buttons
class MapControlColumn extends StatelessWidget {
  final List<MapControlButton> buttons;

  const MapControlColumn({super.key, required this.buttons});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: buttons.expand(
        (btn) => [btn, const SizedBox(height: 8)],
      ).toList(),
    );
  }
}

/// * Zoom controls (+, -, current location)
class ZoomControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onCenterLocation;
  final bool hasPreciseLocation;
  final VoidCallback? onToggleFollow;
  final bool? isFollowing;

  const ZoomControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onCenterLocation,
    this.hasPreciseLocation = false,
    this.onToggleFollow,
    this.isFollowing,
  });

  @override
  Widget build(BuildContext context) {
    return MapControlColumn(
      buttons: [
        MapControlButton(
          icon: Icons.add,
          onTap: onZoomIn,
          tooltip: "Zoom In",
        ),
        MapControlButton(
          icon: Icons.remove,
          onTap: onZoomOut,
          tooltip: "Zoom Out",
        ),
        MapControlButton(
          icon: Icons.my_location,
          onTap: onCenterLocation,
          tooltip: "My Location",
          isActive: hasPreciseLocation,
        ),
        if (onToggleFollow != null && isFollowing != null)
          MapControlButton(
            icon: Icons.navigation,
            onTap: onToggleFollow!,
            tooltip: "Follow Navigation",
            isActive: isFollowing!,
          ),
      ],
    );
  }
}

/// * Search bar overlay
class MapSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final bool isLoading;
  final VoidCallback? onClear;

  const MapSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    this.isLoading = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: AppTheme.surfaceColor,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          hintText: "Search places, roads, landmarks...",
          prefixIcon:
              const Icon(Icons.search, color: AppTheme.textSecondary),
          suffixIcon: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: onClear,
                    )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppTheme.surfaceColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onSubmitted: (_) => onSubmitted(),
      ),
    );
  }
}
