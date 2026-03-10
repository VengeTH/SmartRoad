import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";

import "../models/fuel_station.dart";
import "../models/fuel_type.dart";
import "../providers/fuel_provider.dart";
import "../services/location_service.dart";
import "../services/supabase_service.dart";
import "../utils/fuel_utils.dart";

/// * Dialog for updating multiple fuel prices at once.
/// *
/// * Features:
/// * - Multi-fuel price entry (91/95/97/diesel)
/// * - GPS distance validation (max 200m)
/// * - Photo proof requirement (50m-200m range)
/// * - Rate limit checking
/// * - Real-time validation feedback
class MultiFuelUpdateDialog extends ConsumerStatefulWidget {
  final FuelStation station;
  final VoidCallback onSuccess;

  const MultiFuelUpdateDialog({
    super.key,
    required this.station,
    required this.onSuccess,
  });

  @override
  ConsumerState<MultiFuelUpdateDialog> createState() =>
      _MultiFuelUpdateDialogState();
}

class _MultiFuelUpdateDialogState
    extends ConsumerState<MultiFuelUpdateDialog> {
  final Map<FuelType, TextEditingController> _controllers = {};
  final Map<FuelType, bool> _selectedFuels = {};

  bool _isValidatingLocation = false;
  bool _isSubmitting = false;
  double? _distanceMeters;
  String? _validationMessage;
  bool _requiresPhoto = false;

  XFile? _selectedPhoto;

  @override
  void initState() {
    super.initState();

    // * Initialize controllers and selection state
    for (final fuelType in FuelType.values) {
      _controllers[fuelType] = TextEditingController();
      _selectedFuels[fuelType] = false;

      // * Pre-fill with existing prices if available
      final existingPrice = widget.station.prices
          .where((p) => p.fuelType == fuelType)
          .firstOrNull;
      if (existingPrice != null) {
        _controllers[fuelType]!.text = existingPrice.price.toStringAsFixed(2);
      }
    }

    // * Validate location on open
    _validateLocation();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _validateLocation() async {
    setState(() {
      _isValidatingLocation = true;
      _validationMessage = null;
    });

    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();

      if (position == null) {
        setState(() {
          _validationMessage = "Unable to get your location. Please enable GPS.";
          _isValidatingLocation = false;
        });
        return;
      }

      final distance = FuelUtils.calculateDistance(
        position.latitude,
        position.longitude,
        widget.station.latitude,
        widget.station.longitude,
      );

      final validation = FuelUtils.validateDistance(distance);

      setState(() {
        _distanceMeters = distance;
        _requiresPhoto = validation.requiresPhoto;
        _validationMessage = validation.message;
        _isValidatingLocation = false;
      });
    } catch (e) {
      setState(() {
        _validationMessage = "Location error: ${e.toString()}";
        _isValidatingLocation = false;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1080,
    );

    if (photo != null) {
      setState(() => _selectedPhoto = photo);
    }
  }

  Future<String?> _uploadPhoto() async {
    if (_selectedPhoto == null) return null;

    try {
      final supabaseService = SupabaseService();
      if (supabaseService.isDemoMode) {
        // * In demo mode, simulate upload
        await Future.delayed(const Duration(seconds: 1));
        return "demo_photo_url";
      }

      final client = supabaseService.client;
      if (client == null) {
        throw Exception("Database connection unavailable");
      }

      final bytes = await _selectedPhoto!.readAsBytes();
      final fileName =
          "fuel_proof_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final path = "fuel-proofs/$fileName";

      await client.storage.from("fuel-proofs").uploadBinary(path, bytes);

      final url = client.storage.from("fuel-proofs").getPublicUrl(path);
      return url;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Photo upload failed: ${e.toString()}")),
        );
      }
      return null;
    }
  }

  Future<void> _submit() async {
    // * Validate at least one fuel is selected
    final selectedPrices = <FuelType, double>{};
    for (final entry in _selectedFuels.entries) {
      if (entry.value) {
        final priceText = _controllers[entry.key]!.text.trim();
        if (priceText.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Please enter a price for ${entry.key.displayName}"),
            ),
          );
          return;
        }

        final price = double.tryParse(priceText);
        if (price == null || price <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Invalid price for ${entry.key.displayName}"),
            ),
          );
          return;
        }

        selectedPrices[entry.key] = price;
      }
    }

    if (selectedPrices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one fuel type")),
      );
      return;
    }

    // * Validate location constraints
    if (_validationMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_validationMessage!)),
      );
      return;
    }

    // * Check photo requirement
    if (_requiresPhoto && _selectedPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Photo proof required (you are 50m-200m away)"),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // * Upload photo if required
      String? photoUrl;
      if (_requiresPhoto && _selectedPhoto != null) {
        photoUrl = await _uploadPhoto();
        if (photoUrl == null) {
          setState(() => _isSubmitting = false);
          return;
        }
      }

      // * Submit price update
      await ref.read(fuelSubmissionProvider.notifier).submitPriceUpdate(
            stationId: widget.station.id,
            prices: selectedPrices,
            photoUrl: photoUrl,
          );

      final submissionState = ref.read(fuelSubmissionProvider);
      if (submissionState.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Prices updated successfully! 🎉")),
          );
          Navigator.pop(context);
          widget.onSuccess();
        }
      } else if (submissionState.isError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                submissionState.errorMessage ?? "Update failed",
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // * Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_gas_station,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Update Fuel Prices",
                          style:
                              theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.station.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // * Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // * Location validation status
                    _buildLocationStatus(theme),
                    const SizedBox(height: 16),

                    // * Fuel price inputs
                    Text(
                      "Select fuel types and enter new prices:",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...FuelType.values.map((fuelType) {
                      return _buildFuelInput(theme, fuelType);
                    }),

                    const SizedBox(height: 16),

                    // * Photo section
                    if (_requiresPhoto) ...[
                      _buildPhotoSection(theme),
                      const SizedBox(height: 16),
                    ],

                    // * Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting || _isValidatingLocation
                            ? null
                            : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("Submit Updates"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationStatus(ThemeData theme) {
    if (_isValidatingLocation) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              "Validating your location...",
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    if (_validationMessage != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              size: 20,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _validationMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_distanceMeters != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _requiresPhoto
              ? theme.colorScheme.secondaryContainer
              : theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 20,
              color: _requiresPhoto
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _requiresPhoto
                    ? "Distance: ${_distanceMeters!.toStringAsFixed(0)}m – Photo proof required"
                    : "Distance: ${_distanceMeters!.toStringAsFixed(0)}m – Ready to submit",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _requiresPhoto
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFuelInput(ThemeData theme, FuelType fuelType) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Checkbox(
            value: _selectedFuels[fuelType] ?? false,
            onChanged: (value) {
              setState(() {
                _selectedFuels[fuelType] = value ?? false;
              });
            },
          ),
          Expanded(
            flex: 2,
            child: Text(
              fuelType.displayName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _controllers[fuelType],
              enabled: _selectedFuels[fuelType] ?? false,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                hintText: "₱0.00",
                prefixText: "₱ ",
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.camera_alt,
                size: 20,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                "Photo Proof Required",
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "You are more than 50m away. Please upload a photo showing the station's price board.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedPhoto == null)
            OutlinedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.add_a_photo),
              label: const Text("Take Photo"),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Photo selected: ${_selectedPhoto!.name}",
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    setState(() => _selectedPhoto = null);
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}
