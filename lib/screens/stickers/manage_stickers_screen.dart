/// * Manage Stickers Screen
/// * Allows users to view and upload physical HOA stickers
import "package:flutter/material.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "dart:io";
import "dart:typed_data";
import "../../core/theme/app_theme.dart";
import "../../models/sticker.dart";
import "../../providers/sticker_provider.dart";
import "../../providers/auth_provider.dart";
import "../../services/sticker_verifier_service.dart";
import "../../services/supabase_service.dart";

class ManageStickersScreen extends ConsumerStatefulWidget {
  const ManageStickersScreen({super.key});
  
  @override
  ConsumerState<ManageStickersScreen> createState() => _ManageStickersScreenState();
}

class _ManageStickersScreenState extends ConsumerState<ManageStickersScreen> {
  @override
  Widget build(BuildContext context) {
    final stickersAsync = ref.watch(userStickersProvider);
    final hoasAsync = ref.watch(hoasProvider);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("My Stickers"),
      ),
      body: hoasAsync.when(
        data: (hoas) {
          return stickersAsync.when(
            data: (stickers) {
              return _buildContent(hoas, stickers);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text("Error loading stickers: $error"),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text("Error loading HOAs: $error"),
        ),
      ),
    );
  }
  
  Widget _buildContent(List<HOA> hoas, List<Sticker> stickers) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // * Header
          Text(
            "Manage Your Stickers",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            "Upload physical stickers or view your digital stickers",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXL),
          
          // * Add Physical Sticker Button
          ElevatedButton.icon(
            onPressed: () => _showAddPhysicalStickerDialog(hoas),
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text("I have a physical sticker"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: AppTheme.spacingMD,
                horizontal: AppTheme.spacingLG,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingXL),
          
          // * Current Stickers List
          Text(
            "Your Stickers",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          
          if (stickers.isEmpty)
            _buildEmptyState()
          else
            ...stickers.map((sticker) => _buildStickerCard(sticker)),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.badge_outlined,
            size: 64,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: AppTheme.spacingMD),
          Text(
            "No Stickers Yet",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            "Upload a physical sticker or purchase a digital sticker from your HOA",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStickerCard(Sticker sticker) {
    final isExpired = !sticker.isValid;
    final isPhysical = sticker.isPhysicalSticker;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: isExpired ? AppTheme.errorColor.withOpacity(0.3) : AppTheme.borderColor,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sticker.hoaName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Row(
                      children: [
                        if (isPhysical) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingSM,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                            ),
                            child: Text(
                              "Physical",
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingSM),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingSM,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isExpired 
                                ? AppTheme.errorColor.withOpacity(0.2)
                                : AppTheme.successColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                          ),
                          child: Text(
                            isExpired ? "Expired" : "Active",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isExpired ? AppTheme.errorColor : AppTheme.successColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isPhysical && sticker.stickerPhotoUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  child: Image.network(
                    sticker.stickerPhotoUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: AppTheme.surfaceVariant,
                        child: Icon(
                          Icons.image_not_supported,
                          color: AppTheme.textTertiary,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          _buildInfoRow("Issued", _formatDate(sticker.issuedAt)),
          _buildInfoRow("Expires", _formatDate(sticker.expiresAt)),
          if (!isExpired)
            _buildInfoRow(
              "Days Remaining",
              "${sticker.daysUntilExpiration} days",
              valueColor: sticker.daysUntilExpiration < 30
                  ? AppTheme.warningColor
                  : AppTheme.successColor,
            ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingXS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: valueColor ?? AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
  
  void _showAddPhysicalStickerDialog(List<HOA> hoas) {
    if (hoas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No HOAs available")),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => _AddPhysicalStickerDialog(hoas: hoas),
    );
  }
}

class _AddPhysicalStickerDialog extends ConsumerStatefulWidget {
  final List<HOA> hoas;
  
  const _AddPhysicalStickerDialog({required this.hoas});
  
  @override
  ConsumerState<_AddPhysicalStickerDialog> createState() => _AddPhysicalStickerDialogState();
}

class _AddPhysicalStickerDialogState extends ConsumerState<_AddPhysicalStickerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _stickerNumberController = TextEditingController();
  HOA? _selectedHOA;
  File? _selectedImage;
  Uint8List? _selectedImageBytes; // * For web compatibility
  bool _isVerifying = false;
  bool _isUploading = false;
  
  @override
  void dispose() {
    _stickerNumberController.dispose();
    super.dispose();
  }
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        if (kIsWeb) {
          _selectedImageBytes = bytes;
          _selectedImage = null;
        } else {
          _selectedImage = File(image.path);
          _selectedImageBytes = null;
        }
      });
    }
  }
  
  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        if (kIsWeb) {
          _selectedImageBytes = bytes;
          _selectedImage = null;
        } else {
          _selectedImage = File(image.path);
          _selectedImageBytes = null;
        }
      });
    }
  }
  
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_selectedHOA == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an HOA")),
      );
      return;
    }
    
    if (_selectedImage == null && _selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload a photo of your sticker")),
      );
      return;
    }
    
    setState(() {
      _isVerifying = true;
    });
    
    try {
      // * Verify with AI
      final verifier = StickerVerifierService();
      
      final isVerified = await verifier.verifyStickerImage(
        _selectedImage,
        _selectedHOA!.name,
        imageBytes: _selectedImageBytes,
      );
      
      if (!isVerified) {
        setState(() {
          _isVerifying = false;
        });
        
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Photo Rejected"),
              content: const Text(
                "Photo rejected. Please take a clear photo of your sticker.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
        return;
      }
      
      // * Upload image to Supabase Storage
      setState(() {
        _isVerifying = false;
        _isUploading = true;
      });
      
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        throw Exception("User not logged in");
      }
      
      final fileName = "stickers/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg";
      
      // * Upload image - handle both web and mobile
      String photoUrl;
      if (kIsWeb && _selectedImageBytes != null) {
        // * On web, upload bytes directly
        photoUrl = await SupabaseService().uploadImageBytes(_selectedImageBytes!, fileName);
      } else if (_selectedImage != null) {
        // * On mobile, upload file
        photoUrl = await SupabaseService().uploadImage(_selectedImage!, fileName);
      } else {
        throw Exception("No image to upload");
      }
      
      // * Create sticker in database
      final stickerService = ref.read(stickerServiceProvider);
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(days: 365)); // * 1 year validity
      
      await stickerService.createPhysicalSticker(
        userId: userId,
        hoaId: _selectedHOA!.id,
        stickerNumber: _stickerNumberController.text.trim().isEmpty
            ? null
            : _stickerNumberController.text.trim(),
        stickerPhotoUrl: photoUrl,
        issuedAt: now,
        expiresAt: expiresAt,
      );
      
      // * Refresh stickers
      ref.invalidate(userStickersProvider);
      
      if (mounted) {
        Navigator.of(context).pop(); // * Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sticker uploaded and verified successfully!"),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _isUploading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.backgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Add Physical Sticker",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),
              
              // * HOA Selection
              DropdownButtonFormField<HOA>(
                value: _selectedHOA,
                decoration: const InputDecoration(
                  labelText: "Select HOA",
                  prefixIcon: Icon(Icons.home_work),
                ),
                items: widget.hoas.map((hoa) {
                  return DropdownMenuItem<HOA>(
                    value: hoa,
                    child: Text(hoa.name),
                  );
                }).toList(),
                onChanged: (hoa) {
                  setState(() {
                    _selectedHOA = hoa;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return "Please select an HOA";
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingMD),
              
              // * Sticker Number
              TextFormField(
                controller: _stickerNumberController,
                decoration: const InputDecoration(
                  labelText: "Sticker Number (Optional)",
                  prefixIcon: Icon(Icons.confirmation_number),
                  hintText: "Enter your sticker number if available",
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              
              // * Photo Upload
              Text(
                "Sticker Photo",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              
              if (_selectedImage == null && _selectedImageBytes == null)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _takePhoto,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text("Take Photo"),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMD),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_library),
                        label: const Text("Choose from Gallery"),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      child: kIsWeb && _selectedImageBytes != null
                          ? Image.memory(
                              _selectedImageBytes!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : _selectedImage != null
                              ? Image.file(
                                  _selectedImage!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                          _selectedImageBytes = null;
                        });
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text("Remove Photo"),
                    ),
                  ],
                ),
              
              const SizedBox(height: AppTheme.spacingXL),
              
              // * Submit Button
              if (_isVerifying)
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: AppTheme.spacingMD),
                      Text(
                        "Verifying with AI...",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              else if (_isUploading)
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: AppTheme.spacingMD),
                      Text(
                        "Uploading sticker...",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton(
                  onPressed: _submit,
                  child: const Text("Submit"),
                ),
              
              const SizedBox(height: AppTheme.spacingMD),
              
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Cancel"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

