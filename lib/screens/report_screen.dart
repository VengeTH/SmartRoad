import "dart:io";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "../core/constants/app_constants.dart";
import "../providers/auth_provider.dart";
import "../providers/location_provider.dart";
import "../providers/hazard_provider.dart";
import "../services/storage_service_adapter.dart";
import "../widgets/auth_dialog.dart";

/// * Screen for reporting hazards
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String? _selectedType;
  String? _selectedSeverity;
  File? _selectedImage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  /// * Pick image from gallery
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  /// * Take photo with camera
  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  /// * Show image source selection
  Future<void> _showImageSourceDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Image Source"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Gallery"),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Camera"),
              onTap: () {
                Navigator.of(context).pop();
                _takePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// * Submit hazard report
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedType == null || _selectedSeverity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select hazard type and severity"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final AuthState authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated || authState.user == null) {
      showDialog(
        context: context,
        builder: (context) => const AuthDialog(),
      );
      return;
    }

    final LocationState locationState = ref.read(locationProvider);
    if (locationState.position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to get your location"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      String? imageUrl;

      // * Upload image if selected
      if (_selectedImage != null) {
        final String tempHazardId = DateTime.now().millisecondsSinceEpoch.toString();
        imageUrl = await StorageServiceAdapter.instance.uploadHazardImage(
          imageFile: _selectedImage!,
          hazardId: tempHazardId,
        );
      }

      // * Create hazard
      final bool success = await ref.read(hazardsProvider.notifier).createHazard(
            userId: authState.user!.id,
            type: _selectedType!,
            description: _descriptionController.text.trim(),
            severity: _selectedSeverity!,
            lat: locationState.position!.latitude,
            lng: locationState.position!.longitude,
            imageUrl: imageUrl,
          );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Hazard reported successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.read(hazardsProvider).error ?? "Failed to report hazard",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Report Hazard"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // * Hazard type selection
              Text(
                "Hazard Type",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.hazardTypes.map((type) {
                  final bool isSelected = _selectedType == type;
                  return FilterChip(
                    label: Text(type.toUpperCase()),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedType = selected ? type : null;
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // * Severity selection
              Text(
                "Severity",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.severityLevels.map((severity) {
                  final bool isSelected = _selectedSeverity == severity;
                  Color? chipColor;
                  if (severity == "High") {
                    chipColor = Colors.red;
                  } else if (severity == "Medium") {
                    chipColor = Colors.orange;
                  } else {
                    chipColor = Colors.yellow;
                  }

                  return FilterChip(
                    label: Text(severity),
                    selected: isSelected,
                    selectedColor: chipColor.withOpacity(0.3),
                    checkmarkColor: chipColor,
                    onSelected: (selected) {
                      setState(() {
                        _selectedSeverity = selected ? severity : null;
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // * Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: "Description",
                  hintText: "Describe the hazard in detail...",
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter a description";
                  }
                  if (value.trim().length < 10) {
                    return "Description must be at least 10 characters";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // * Image selection
              Text(
                "Image (Optional)",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              if (_selectedImage != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImage!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _selectedImage = null;
                          });
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: _showImageSourceDialog,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text("Add Image"),
                ),

              const SizedBox(height: 32),

              // * Submit button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Submit Report"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

