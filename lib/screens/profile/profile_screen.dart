import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "dart:io";
import "../../providers/auth_provider.dart";
import "../../services/supabase_service.dart";
import "../../models/user_profile.dart";
import "../../core/theme/app_theme.dart";
import "../auth/login_screen.dart";

/// * Profile screen
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Profile")),
        body: const Center(
          child: Text("Please log in to view your profile"),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await SupabaseService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return _ProfileContent(profile: profile);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text("Error: $error"),
        ),
      ),
    );
  }
}

class _ProfileContent extends StatefulWidget {
  final UserProfile profile;
  
  const _ProfileContent({required this.profile});
  
  @override
  State<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<_ProfileContent> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isUpdating = false;
  File? _selectedImage;
  
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name ?? "");
    _emailController = TextEditingController(text: widget.profile.email ?? "");
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }
  
  Future<void> _updateProfile() async {
    setState(() => _isUpdating = true);
    
    try {
      String? imageUrl;
      
      // * Upload new image if selected
      if (_selectedImage != null) {
        final fileName = "${widget.profile.id}_${DateTime.now().millisecondsSinceEpoch}.jpg";
        imageUrl = await SupabaseService().uploadImage(_selectedImage!, fileName);
      }
      
      // * Update profile
      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
      };
      
      if (imageUrl != null) {
        updates['photo_url'] = imageUrl;
      }
      
      await SupabaseService().updateProfile(widget.profile.id, updates);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully")),
        );
        setState(() => _selectedImage = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.spacingMD),
          // * Profile Photo Section
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryColor,
                    width: 3,
                  ),
                  boxShadow: AppTheme.shadowMedium,
                ),
                child: CircleAvatar(
                  radius: 64,
                  backgroundColor: AppTheme.surfaceVariant,
                backgroundImage: _selectedImage != null
                    ? FileImage(_selectedImage!)
                    : widget.profile.photoUrl != null
                        ? NetworkImage(widget.profile.photoUrl!)
                        : null,
                onBackgroundImageError: (exception, stackTrace) {
                  // * Handle image load error
                },
                child: widget.profile.photoUrl == null && _selectedImage == null
                      ? Icon(
                          Icons.person,
                          size: 64,
                          color: AppTheme.textSecondary,
                        )
                    : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.backgroundColor,
                      width: 3,
                    ),
                    boxShadow: AppTheme.shadowSmall,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, size: 20),
                    onPressed: _pickImage,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXL),
          // * Name Field
          TextField(
            controller: _nameController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: "Full Name",
              prefixIcon: Icon(Icons.person_outline, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          // * Email (read-only)
          TextField(
            controller: _emailController,
            style: const TextStyle(color: AppTheme.textSecondary),
            decoration: const InputDecoration(
              labelText: "Email",
              prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textSecondary),
            ),
            readOnly: true,
            enabled: false,
          ),
          const SizedBox(height: AppTheme.spacingLG),
          // * Stats Cards
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    child: Column(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: AppTheme.warningColor,
                          size: 32,
                        ),
                        const SizedBox(height: AppTheme.spacingSM),
                        Text(
                          widget.profile.reporterLevel.value,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
            ),
          ),
                        const SizedBox(height: 4),
                        Text(
                          "Reporter Level",
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.successColor,
                          size: 32,
                        ),
                        const SizedBox(height: AppTheme.spacingSM),
                        Text(
                          "${widget.profile.validReportsCount}",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Valid Reports",
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
            ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXL),
          // * Update Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
            onPressed: _isUpdating ? null : _updateProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMD),
              ),
            child: _isUpdating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                  )
                : const Text("Update Profile"),
            ),
          ),
        ],
      ),
    );
  }
}

