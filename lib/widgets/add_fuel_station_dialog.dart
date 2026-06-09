import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "package:latlong2/latlong.dart";

import "../providers/fuel_provider.dart";
import "../services/supabase_service.dart";

/// * Dialog for adding a new fuel station to the map.
/// *
/// * Features:
/// * - Station name and brand input
/// * - Location from tapped coordinates or map center
/// * - Province/city/region selection or auto-fill
/// * - Optional photo attachment
/// * - Reverse geocoding support (if available)
class AddFuelStationDialog extends ConsumerStatefulWidget {
  final LatLng location;
  final VoidCallback onSuccess;

  const AddFuelStationDialog({
    super.key,
    required this.location,
    required this.onSuccess,
  });

  @override
  ConsumerState<AddFuelStationDialog> createState() =>
      _AddFuelStationDialogState();
}

class _AddFuelStationDialogState extends ConsumerState<AddFuelStationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _provinceController = TextEditingController();
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();

  XFile? _selectedPhoto;
  bool _isUploadingPhoto = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // * Pre-fill Metro Manila as default for demo
    _provinceController.text = "Metro Manila";
    _cityController.text = "Quezon City";
    _regionController.text = "NCR";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _provinceController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    super.dispose();
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

    setState(() => _isUploadingPhoto = true);

    try {
      final supabaseService = SupabaseService();
      if (supabaseService.isDemoMode) {
        // * In demo mode, simulate upload
        await Future.delayed(const Duration(seconds: 1));
        setState(() => _isUploadingPhoto = false);
        return "demo_station_photo_url";
      }

      final client = supabaseService.client as dynamic;
      if (client == null) {
        throw Exception("Database connection unavailable");
      }

      final bytes = await _selectedPhoto!.readAsBytes();
      final fileName = "station_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final path = "fuel-stations/$fileName";

      await client.storage.from("fuel-stations").uploadBinary(path, bytes);

      final url = client.storage.from("fuel-stations").getPublicUrl(path);

      setState(() => _isUploadingPhoto = false);
      return url;
    } catch (e) {
      setState(() => _isUploadingPhoto = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Photo upload failed: ${e.toString()}")),
        );
      }
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // * Upload photo if provided
      String? photoUrl;
      if (_selectedPhoto != null) {
        photoUrl = await _uploadPhoto();
        if (photoUrl == null && _selectedPhoto != null) {
          // * Upload failed but was required
          setState(() => _isSubmitting = false);
          return;
        }
      }

      // * Submit new station
      final stationId = await ref
          .read(fuelSubmissionProvider.notifier)
          .submitNewStation(
            name: _nameController.text.trim(),
            latitude: widget.location.latitude,
            longitude: widget.location.longitude,
            brand:
                _brandController.text.trim().isNotEmpty
                    ? _brandController.text.trim()
                    : null,
            province: _provinceController.text.trim(),
            city: _cityController.text.trim(),
            region:
                _regionController.text.trim().isNotEmpty
                    ? _regionController.text.trim()
                    : null,
            photoUrl: photoUrl,
          );

      final submissionState = ref.read(fuelSubmissionProvider);
      if (submissionState.isSuccess && stationId != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Station submitted! It will appear after admin verification.",
              ),
            ),
          );
          Navigator.pop(context);
          widget.onSuccess();
        }
      } else if (submissionState.isError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                submissionState.errorMessage ?? "Submission failed",
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.add_location,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Add Fuel Station",
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // * Info message
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Station will be reviewed by admins before appearing on the map.",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // * Station name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: "Station Name *",
                          hintText: "e.g., Shell EDSA Ortigas",
                          prefixIcon: Icon(Icons.local_gas_station),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Station name is required";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // * Brand (optional)
                      TextFormField(
                        controller: _brandController,
                        decoration: const InputDecoration(
                          labelText: "Brand (Optional)",
                          hintText: "e.g., Shell, Petron, Caltex",
                          prefixIcon: Icon(Icons.business),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // * Province
                      TextFormField(
                        controller: _provinceController,
                        decoration: const InputDecoration(
                          labelText: "Province *",
                          hintText: "e.g., Metro Manila",
                          prefixIcon: Icon(Icons.map),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Province is required";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // * City
                      TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: "City *",
                          hintText: "e.g., Quezon City",
                          prefixIcon: Icon(Icons.location_city),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "City is required";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // * Region (optional)
                      TextFormField(
                        controller: _regionController,
                        decoration: const InputDecoration(
                          labelText: "Region (Optional)",
                          hintText: "e.g., NCR, Region III",
                          prefixIcon: Icon(Icons.public),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // * Photo section
                      Text(
                        "Station Photo (Optional)",
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_selectedPhoto == null)
                        OutlinedButton.icon(
                          onPressed: _pickPhoto,
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text("Add Photo"),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedPhoto!.name,
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
                        ),
                      const SizedBox(height: 16),

                      // * Location display
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Location: ${widget.location.latitude.toStringAsFixed(6)}, ${widget.location.longitude.toStringAsFixed(6)}",
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // * Submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              _isSubmitting || _isUploadingPhoto
                                  ? null
                                  : _submit,
                          child:
                              _isSubmitting
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text("Submit Station"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

