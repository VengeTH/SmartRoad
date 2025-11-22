import "dart:io";
import "package:supabase_flutter/supabase_flutter.dart";
import "../core/config/supabase_config.dart";
import "../core/constants/app_constants.dart";

/// * Storage service for handling file uploads
class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  /// * Upload hazard image
  Future<String> uploadHazardImage({
    required File imageFile,
    required String hazardId,
  }) async {
    try {
      final String fileName = "$hazardId-${DateTime.now().millisecondsSinceEpoch}.jpg";
      final String filePath = "$hazardId/$fileName";

      await SupabaseConfig.client.storage
          .from(AppConstants.hazardImagesBucket)
          .upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(
              contentType: "image/jpeg",
              upsert: false,
            ),
          );

      // * Get public URL
      final String imageUrl = SupabaseConfig.client.storage
          .from(AppConstants.hazardImagesBucket)
          .getPublicUrl(filePath);

      return imageUrl;
    } catch (e) {
      throw Exception("Failed to upload image: ${e.toString()}");
    }
  }

  /// * Upload profile image
  Future<String> uploadProfileImage({
    required File imageFile,
    required String userId,
  }) async {
    try {
      final String fileName = "$userId-${DateTime.now().millisecondsSinceEpoch}.jpg";
      final String filePath = "$userId/$fileName";

      await SupabaseConfig.client.storage
          .from(AppConstants.profileImagesBucket)
          .upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(
              contentType: "image/jpeg",
              upsert: false,
            ),
          );

      // * Get public URL
      final String imageUrl = SupabaseConfig.client.storage
          .from(AppConstants.profileImagesBucket)
          .getPublicUrl(filePath);

      return imageUrl;
    } catch (e) {
      throw Exception("Failed to upload profile image: ${e.toString()}");
    }
  }

  /// * Delete image
  Future<void> deleteImage({
    required String bucket,
    required String filePath,
  }) async {
    try {
      await SupabaseConfig.client.storage.from(bucket).remove([filePath]);
    } catch (e) {
      throw Exception("Failed to delete image: ${e.toString()}");
    }
  }
}

