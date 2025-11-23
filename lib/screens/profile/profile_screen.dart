import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "dart:io";
import "../../providers/auth_provider.dart";
import "../../services/supabase_service.dart";
import "../../models/user_profile.dart";
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // * Profile Photo
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundImage: _selectedImage != null
                    ? FileImage(_selectedImage!)
                    : widget.profile.photoUrl != null
                        ? NetworkImage(widget.profile.photoUrl!)
                        : null,
                onBackgroundImageError: (exception, stackTrace) {
                  // * Handle image load error
                },
                child: widget.profile.photoUrl == null && _selectedImage == null
                    ? const Icon(Icons.person, size: 60)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, size: 20),
                    onPressed: _pickImage,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // * Name Field
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: "Name",
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          // * Email (read-only)
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: "Email",
              prefixIcon: Icon(Icons.email),
            ),
            readOnly: true,
            enabled: false,
          ),
          const SizedBox(height: 16),
          // * Reporter Level
          Card(
            child: ListTile(
              leading: const Icon(Icons.star),
              title: const Text("Reporter Level"),
              subtitle: Text(widget.profile.reporterLevel.value),
            ),
          ),
          const SizedBox(height: 8),
          // * Valid Reports Count
          Card(
            child: ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text("Valid Reports"),
              subtitle: Text("${widget.profile.validReportsCount} reports"),
            ),
          ),
          const SizedBox(height: 24),
          // * Update Button
          ElevatedButton(
            onPressed: _isUpdating ? null : _updateProfile,
            child: _isUpdating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Update Profile"),
          ),
        ],
      ),
    );
  }
}

