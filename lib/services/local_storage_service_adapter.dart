import "dart:io";
import "package:flutter/foundation.dart";
import "local_storage_service.dart";

/// * Local storage adapter for image uploads (stores images locally)
class LocalStorageServiceAdapter {
  LocalStorageServiceAdapter._();

  static final LocalStorageServiceAdapter instance = LocalStorageServiceAdapter._();

  /// * Upload hazard image (saves locally)
  Future<String> uploadHazardImage({
    required File imageFile,
    required String hazardId,
  }) async {
    try {
      final String fileName =
          "$hazardId-${DateTime.now().millisecondsSinceEpoch}.jpg";
      final String filePath =
          await LocalStorageService.instance.saveImageFile(imageFile, fileName);
      
      // * For web, return a data URL format
      if (kIsWeb) {
        return "local://$filePath";
      }
      return filePath;
    } catch (e) {
      throw Exception("Failed to upload image: ${e.toString()}");
    }
  }

  /// * Upload profile image (saves locally)
  Future<String> uploadProfileImage({
    required File imageFile,
    required String userId,
  }) async {
    try {
      final String fileName =
          "$userId-${DateTime.now().millisecondsSinceEpoch}.jpg";
      final String filePath =
          await LocalStorageService.instance.saveImageFile(imageFile, fileName);
      
      // * For web, return a data URL format
      if (kIsWeb) {
        return "local://$filePath";
      }
      return filePath;
    } catch (e) {
      throw Exception("Failed to upload profile image: ${e.toString()}");
    }
  }

  /// * Get image file from path
  File? getImageFile(String filePath) {
    return LocalStorageService.instance.getImageFile(filePath);
  }
}

