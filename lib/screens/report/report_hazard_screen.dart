import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "dart:io";
import "../../models/hazard.dart";
import "../../services/supabase_service.dart";
import "../../services/location_service.dart";
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
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Report Hazard"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // * Header Section
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLG),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.warningColor,
                      size: 32,
                    ),
                    const SizedBox(width: AppTheme.spacingMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Report a Road Hazard",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Help keep roads safe for everyone",
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),
              // * Hazard Type Selection
              Text(
                "Hazard Type",
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Wrap(
                spacing: AppTheme.spacingSM,
                runSpacing: AppTheme.spacingSM,
                children: HazardType.values.map((type) {
                  return FilterChip(
                    label: Text(type.value),
                    selected: _selectedType == type,
                    onSelected: (selected) {
                      setState(() => _selectedType = selected ? type : null);
                    },
                    selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                    checkmarkColor: AppTheme.primaryColor,
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTheme.spacingXL),
              // * Severity Selection
              Text(
                "Severity Level",
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Wrap(
                spacing: AppTheme.spacingSM,
                runSpacing: AppTheme.spacingSM,
                children: SeverityLevel.values.map((severity) {
                  Color severityColor;
                  switch (severity) {
                    case SeverityLevel.low:
                      severityColor = AppTheme.successColor;
                      break;
                    case SeverityLevel.medium:
                      severityColor = AppTheme.warningColor;
                      break;
                    case SeverityLevel.high:
                      severityColor = AppTheme.errorColor;
                      break;
                  }
                  
                  return FilterChip(
                    label: Text(severity.value),
                    selected: _selectedSeverity == severity,
                    onSelected: (selected) {
                      setState(() => _selectedSeverity = selected ? severity : null);
                    },
                    selectedColor: severityColor.withOpacity(0.2),
                    checkmarkColor: severityColor,
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTheme.spacingXL),
              // * Description
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: "Description",
                  hintText: "Describe the hazard in detail (location, size, impact, etc.)",
                  prefixIcon: Icon(Icons.description_outlined, color: AppTheme.textSecondary),
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
              const SizedBox(height: AppTheme.spacingXL),
              // * Image Picker
              if (_selectedImage != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                      child: Stack(
                        children: [
                          Image.file(
                            _selectedImage!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: AppTheme.spacingSM,
                            right: AppTheme.spacingSM,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => setState(() => _selectedImage = null),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text("Add Photo (Optional)"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMD),
                  ),
                ),
              const SizedBox(height: AppTheme.spacingXXL),
              // * Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitReport,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_isLoading ? "Submitting..." : "Submit Report"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMD),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

