import "dart:io";
import "../core/config/app_config.dart";
import "storage_service.dart";
import "local_storage_service_adapter.dart";

/// * Storage service adapter - switches between local and Supabase
class StorageServiceAdapter {
  StorageServiceAdapter._();

  static final StorageServiceAdapter instance = StorageServiceAdapter._();

  /// * Upload hazard image
  Future<String> uploadHazardImage({
    required File imageFile,
    required String hazardId,
  }) async {
    if (AppConfig.useLocalStorage) {
      return await LocalStorageServiceAdapter.instance.uploadHazardImage(
        imageFile: imageFile,
        hazardId: hazardId,
      );
    } else {
      return await StorageService.instance.uploadHazardImage(
        imageFile: imageFile,
        hazardId: hazardId,
      );
    }
  }

  /// * Upload profile image
  Future<String> uploadProfileImage({
    required File imageFile,
    required String userId,
  }) async {
    if (AppConfig.useLocalStorage) {
      return await LocalStorageServiceAdapter.instance.uploadProfileImage(
        imageFile: imageFile,
        userId: userId,
      );
    } else {
      return await StorageService.instance.uploadProfileImage(
        imageFile: imageFile,
        userId: userId,
      );
    }
  }
}

