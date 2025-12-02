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
    final isMobile = AppTheme.isMobile(context);
    final padding = AppTheme.responsivePadding(context);
    final maxWidth = AppTheme.maxContentWidth(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Report Hazard"),
        elevation: 0,
      ),
      body: Center(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
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
                spacing: isMobile ? AppTheme.spacingSM : AppTheme.spacingMD,
                runSpacing: isMobile ? AppTheme.spacingSM : AppTheme.spacingMD,
                children: HazardType.values.map((type) {
                  // * Capitalize first letter for display
                  final displayName = type.value[0].toUpperCase() + type.value.substring(1);
                  final isSelected = _selectedType == type;
                  return FilterChip(
                    label: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 2 : 4,
                      ),
                      child: Text(
                        displayName,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedType = selected ? type : null);
                    },
                    selectedColor: AppTheme.primaryColor.withOpacity(0.25),
                    checkmarkColor: AppTheme.primaryColor,
                    backgroundColor: AppTheme.surfaceVariant,
                    side: BorderSide(
                      color: isSelected 
                          ? AppTheme.primaryColor 
                          : AppTheme.borderColor,
                      width: isSelected ? 2.0 : 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    elevation: isSelected ? 2 : 0,
                    pressElevation: 4,
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
                spacing: isMobile ? AppTheme.spacingSM : AppTheme.spacingMD,
                runSpacing: isMobile ? AppTheme.spacingSM : AppTheme.spacingMD,
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
                  
                  final isSelected = _selectedSeverity == severity;
                  return FilterChip(
                    label: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 2 : 4,
                      ),
                      child: Text(
                        severity.value,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedSeverity = selected ? severity : null);
                    },
                    selectedColor: severityColor.withOpacity(0.25),
                    checkmarkColor: severityColor,
                    backgroundColor: AppTheme.surfaceVariant,
                    side: BorderSide(
                      color: isSelected 
                          ? severityColor 
                          : AppTheme.borderColor,
                      width: isSelected ? 2.0 : 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    elevation: isSelected ? 2 : 0,
                    pressElevation: 4,
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTheme.spacingXL),
              // * Description
              TextFormField(
                controller: _descriptionController,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: isMobile ? 15 : 16,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  labelText: "Description",
                  hintText: "Describe the hazard in detail (location, size, impact, etc.)",
                  prefixIcon: const Icon(
                    Icons.description_outlined, 
                    color: AppTheme.textSecondary,
                    size: 24,
                  ),
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
                minLines: 5,
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
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(
                      Icons.camera_alt_outlined,
                      size: 22,
                    ),
                    label: const Text("Add Photo (Optional)"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingXL,
                        vertical: AppTheme.spacingLG,
                      ),
                    ),
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
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          size: 22,
                        ),
                  label: Text(
                    _isLoading ? "Submitting..." : "Submit Report",
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? AppTheme.spacingLG : AppTheme.spacingXL,
                      vertical: isMobile ? AppTheme.spacingMD : AppTheme.spacingLG,
                    ),
                    minimumSize: Size(0, AppTheme.responsiveButtonHeight(context)),
                    elevation: 3,
                    shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                  ),
                ),
              ),
                ],
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }
}

