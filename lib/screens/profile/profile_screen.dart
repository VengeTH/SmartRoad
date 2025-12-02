import "package:flutter/material.dart";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "dart:io";
import "../../providers/auth_provider.dart";
import "../../services/supabase_service.dart";
import "../../models/user_profile.dart";
import "../../core/theme/app_theme.dart";
import "../auth/login_screen.dart";
import "../gate/gate_pass_screen.dart";
import "../gate/guard_scanner_screen.dart";
import "../stickers/manage_stickers_screen.dart";

/// * Profile screen
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    
    debugPrint("🔍 [ProfileScreen] UserId: $userId");
    debugPrint("🔍 [ProfileScreen] Profile state: ${profileAsync.valueOrNull?.name ?? 'null'}");
    debugPrint("🔍 [ProfileScreen] Has error: ${profileAsync.hasError}");
    if (profileAsync.hasError) {
      debugPrint("🔍 [ProfileScreen] Error: ${profileAsync.error}");
    }
    
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
            // * Profile is null - this shouldn't happen in demo mode
            // * Try to refresh
            debugPrint("⚠️ [ProfileScreen] Profile is null, attempting refresh");
            Future.microtask(() {
              ref.invalidate(currentUserProfileProvider);
            });
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: AppTheme.spacingMD),
                  Text("Loading profile..."),
                ],
              ),
            );
          }
          
          debugPrint("✅ [ProfileScreen] Profile loaded successfully: ${profile.name}");
          return _ProfileContent(profile: profile);
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppTheme.spacingMD),
              Text("Loading profile..."),
            ],
          ),
        ),
        error: (error, stack) {
          debugPrint("Profile error: $error");
          debugPrint("Stack: $stack");
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingXL),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.errorColor,
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  Text(
                    "Something went wrong",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(
                    "Please try again",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXL),
                  ElevatedButton(
                    onPressed: () {
                      // * Refresh the profile
                      ref.invalidate(currentUserProfileProvider);
                    },
                    child: const Text("Retry"),
                  ),
                ],
              ),
            ),
          );
        },
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
                  onBackgroundImageError: _selectedImage != null || widget.profile.photoUrl != null
                      ? (exception, stackTrace) {
                          // * Handle image load error
                          debugPrint("Error loading profile image: $exception");
                        }
                      : null,
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
          
          // * Gate Pass Card
          Card(
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GatePassScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: Icon(
                        Icons.qr_code_scanner,
                        color: AppTheme.primaryColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Gate Pass",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Show QR code for gate access",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppTheme.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          // * Manage Stickers Card
          Card(
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ManageStickersScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: Icon(
                        Icons.badge,
                        color: AppTheme.primaryColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "My Stickers",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Manage and upload physical stickers",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppTheme.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          // * Guard Scanner Card (for testing)
          Card(
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GuardScannerScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      decoration: BoxDecoration(
                        color: AppTheme.infoColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: Icon(
                        Icons.qr_code_scanner_outlined,
                        color: AppTheme.infoColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Guard Scanner",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Scan QR codes to validate gate passes",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppTheme.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
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

