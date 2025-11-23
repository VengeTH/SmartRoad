import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "dart:io";
import "../../models/hazard.dart";
import "../../services/supabase_service.dart";
import "../../services/location_service.dart";
import "../../providers/location_provider.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_theme.dart";

/// * Screen for reporting a new hazard
class ReportHazardScreen extends ConsumerStatefulWidget {
  const ReportHazardScreen({super.key});
  
  @override
  ConsumerState<ReportHazardScreen> createState() => _ReportHazardScreenState();
}

class _ReportHazardScreenState extends ConsumerState<ReportHazardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  
  HazardType? _selectedType;
  SeverityLevel? _selectedSeverity;
  File? _selectedImage;
  bool _isLoading = false;
  
  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    
    if (image != null) {
      final file = File(image.path);
      final size = await file.length();
      
      if (size > AppConstants.maxImageSizeBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Image too large. Maximum size is 5MB."),
            ),
          );
        }
        return;
      }
      
      setState(() => _selectedImage = file);
    }
  }
  
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a hazard type")),
      );
      return;
    }
    if (_selectedSeverity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a severity level")),
      );
      return;
    }
    
    // * Check authentication
    if (!SupabaseService().isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in to report hazards")),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // * Get current location
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();
      
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Unable to get your location")),
          );
        }
        return;
      }
      
      // * Upload image if selected
      String? imageUrl;
      if (_selectedImage != null) {
        final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
        imageUrl = await SupabaseService().uploadImage(_selectedImage!, fileName);
      }
      
      // * Create hazard
      await SupabaseService().createHazard(
        type: _selectedType!,
        description: _descriptionController.text.trim(),
        severity: _selectedSeverity!,
        latitude: position.latitude,
        longitude: position.longitude,
        imageUrl: imageUrl,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Hazard reported successfully!")),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
              // * Hazard Type Selection
              const Text(
                "Hazard Type",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: HazardType.values.map((type) {
                  return ChoiceChip(
                    label: Text(type.value),
                    selected: _selectedType == type,
                    onSelected: (selected) {
                      setState(() => _selectedType = selected ? type : null);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              // * Severity Selection
              const Text(
                "Severity",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SeverityLevel.values.map((severity) {
                  return ChoiceChip(
                    label: Text(severity.value),
                    selected: _selectedSeverity == severity,
                    onSelected: (selected) {
                      setState(() => _selectedSeverity = selected ? severity : null);
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
                  hintText: "Describe the hazard in detail",
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
              // * Image Picker
              if (_selectedImage != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImage!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setState(() => _selectedImage = null),
                      child: const Text("Remove Image"),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Add Photo"),
                ),
              const SizedBox(height: 32),
              // * Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _submitReport,
                child: _isLoading
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

