import "package:flutter/material.dart";
import "../services/route_service.dart";
import "../services/routing_service.dart";
import "../core/theme/app_theme.dart";
import "package:latlong2/latlong.dart";

/// * Dialog for saving a route
class SaveRouteDialog extends StatefulWidget {
  final List<LatLng> routePoints;
  final LatLng startPoint;
  final LatLng endPoint;
  final int distanceMeters;
  final Duration duration;
  final VehicleType vehicleType;
  final VoidCallback? onEditRoute; // * Callback to edit route
  
  const SaveRouteDialog({
    super.key,
    required this.routePoints,
    required this.startPoint,
    required this.endPoint,
    required this.distanceMeters,
    required this.duration,
    required this.vehicleType,
    this.onEditRoute,
  });
  
  @override
  State<SaveRouteDialog> createState() => _SaveRouteDialogState();
}

class _SaveRouteDialogState extends State<SaveRouteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController(text: "0");
  
  bool _isPublic = true;
  bool _isSaving = false;
  
  // * Tags
  final Map<String, bool> _tags = {
    'rain_safe': false,
    'flood_safe': false,
    'toll_free': false,
    'gate_aware': false,
    'night_safe': false,
  };
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }
  
  Future<void> _saveRoute() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final routeService = RouteService();
      
      // * Build tags map (only include true values)
      final tags = <String, dynamic>{};
      _tags.forEach((key, value) {
        if (value) tags[key] = true;
      });
      
      // * Private routes cannot be sold (price must be 0)
      final priceCents = _isPublic ? (int.tryParse(_priceController.text) ?? 0) : 0;
      
      final savedRoute = await routeService.saveCurrentRoute(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        geometry: widget.routePoints,
        startPoint: widget.startPoint,
        endPoint: widget.endPoint,
        distanceMeters: widget.distanceMeters,
        estimatedDurationSeconds: widget.duration.inSeconds,
        vehicleType: widget.vehicleType,
        tags: tags.isEmpty ? null : tags,
        priceCents: priceCents,
        isPublic: _isPublic,
      );
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Route '${savedRoute.name}' saved successfully!"),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving route: $e"),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Save Route"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // * Route info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.vehicleType.icon,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${(widget.distanceMeters / 1000).toStringAsFixed(1)} km",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _formatDuration(widget.duration),
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // * Edit Route button - Always show if we have route points
              if (widget.onEditRoute != null)
                OutlinedButton.icon(
                  onPressed: widget.onEditRoute,
                  icon: const Icon(Icons.edit_location_alt, size: 18),
                  label: const Text("Adjust Route Path"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
              if (widget.onEditRoute != null) const SizedBox(height: 16),
              // * Show message if edit route not available
              if (widget.onEditRoute == null && widget.routePoints.length > 1)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Edit route available for navigation routes only",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // * Route name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Route Name *",
                  hintText: "e.g., Makati to BGC via EDSA",
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter a route name";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // * Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: "Description (Optional)",
                  hintText: "Add details about this route...",
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              // * Tags
              const Text(
                "Tags",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.entries.map((entry) {
                  return FilterChip(
                    label: Text(_getTagLabel(entry.key)),
                    selected: entry.value,
                    onSelected: (selected) {
                      setState(() {
                        _tags[entry.key] = selected;
                      });
                    },
                    avatar: Icon(
                      _getTagIcon(entry.key),
                      size: 18,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // * Public/Private toggle (must be first to control price)
              SwitchListTile(
                title: const Text("Make Public"),
                subtitle: Text(_isPublic
                    ? "Others can discover and use this route"
                    : "Private route - only you can access it"),
                value: _isPublic,
                onChanged: (value) {
                  setState(() {
                    _isPublic = value;
                    // * If making private, set price to 0 (private routes can't be sold)
                    if (!value) {
                      _priceController.text = "0";
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              // * Price (only enabled if public)
              TextFormField(
                controller: _priceController,
                enabled: _isPublic, // * Disable if private
                decoration: InputDecoration(
                  labelText: "Price (PHP)",
                  hintText: _isPublic ? "0 = Free" : "Private routes cannot be sold",
                  prefixText: "₱",
                  helperText: _isPublic
                      ? "Set price in Philippine Peso (0 for free)"
                      : "Make route public to set a price",
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (!_isPublic) {
                    // * Private routes always have price 0
                    return null;
                  }
                  if (value == null || value.isEmpty) {
                    return "Please enter a price (0 for free)";
                  }
                  final price = int.tryParse(value);
                  if (price == null || price < 0) {
                    return "Price must be a positive number";
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveRoute,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("Save Route"),
        ),
      ],
    );
  }
  
  String _getTagLabel(String tag) {
    switch (tag) {
      case 'rain_safe':
        return 'Rain Safe';
      case 'flood_safe':
        return 'Flood Safe';
      case 'toll_free':
        return 'Toll Free';
      case 'gate_aware':
        return 'Gate Aware';
      case 'night_safe':
        return 'Night Safe';
      default:
        return tag;
    }
  }
  
  IconData _getTagIcon(String tag) {
    switch (tag) {
      case 'rain_safe':
        return Icons.water_drop;
      case 'flood_safe':
        return Icons.waves;
      case 'toll_free':
        return Icons.money_off;
      case 'gate_aware':
        return Icons.security;
      case 'night_safe':
        return Icons.nightlight;
      default:
        return Icons.check_circle;
    }
  }
  
  /// * Format duration to show days, hours, and minutes
  String _formatDuration(Duration duration) {
    final totalMinutes = duration.inMinutes;
    final days = totalMinutes ~/ (24 * 60);
    final hours = (totalMinutes % (24 * 60)) ~/ 60;
    final minutes = totalMinutes % 60;
    
    if (days > 0) {
      // * 24 hours or more: show days, hours, and minutes
      final parts = <String>[];
      parts.add("$days day${days != 1 ? 's' : ''}");
      if (hours > 0) {
        parts.add("$hours hour${hours != 1 ? 's' : ''}");
      }
      if (minutes > 0) {
        parts.add("$minutes min${minutes != 1 ? 's' : ''}");
      }
      return parts.join(", ");
    } else if (hours > 0) {
      // * Less than 24 hours but more than 0: show hours and minutes
      if (minutes > 0) {
        return "$hours hour${hours != 1 ? 's' : ''} $minutes min${minutes != 1 ? 's' : ''}";
      } else {
        return "$hours hour${hours != 1 ? 's' : ''}";
      }
    } else {
      // * Less than 1 hour: show only minutes
      return "$minutes min${minutes != 1 ? 's' : ''}";
    }
  }
}
