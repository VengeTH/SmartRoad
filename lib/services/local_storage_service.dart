import "dart:convert";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:shared_preferences/shared_preferences.dart";

// * Conditional imports - path_provider only on non-web platforms
import "path_provider_loader_stub.dart"
    if (dart.library.io) "path_provider_loader.dart" as path_loader;

// * Import File and Directory - stub on web, real on mobile
import "file_stub.dart" if (dart.library.io) "dart:io" show File, Directory;

/// * Local storage service for file-based data persistence
/// * Works on mobile (file-based) and web (SharedPreferences-based)
class LocalStorageService {
  LocalStorageService._();

  static final LocalStorageService instance = LocalStorageService._();
  static dynamic _documentsDirectory; // * Can be Directory or null
  static bool _isWeb = kIsWeb;

  /// * Initialize local storage
  Future<void> initialize() async {
    // * CRITICAL: Check kIsWeb FIRST - never use path_provider on web
    // * This check MUST happen before ANY path_provider code
    if (kIsWeb) {
      // * For web, ONLY use SharedPreferences - never touch path_provider
      try {
        await SharedPreferences.getInstance();
        debugPrint("✅ Local storage initialized (Web - SharedPreferences)");
      } catch (e) {
        debugPrint("⚠️ SharedPreferences initialization warning: $e");
      }
      // * CRITICAL: Return immediately - do NOT proceed to path_provider code
      return;
    }

    // * Mobile platforms ONLY - use path_provider
    // * This code will NEVER execute on web due to early return above
    if (kIsWeb) {
      // * This should never execute, but double-check
      debugPrint("❌ ERROR: Mobile path_provider code reached on web!");
      return;
    }

    try {
      // * Only call path_provider on mobile - conditional import ensures stub on web
      // * But we've already returned if kIsWeb, so this is safe
      _documentsDirectory = await _getDocumentsDirectoryMobile();
      if (_documentsDirectory == null) {
        debugPrint("⚠️ path_provider not available, using SharedPreferences only");
        return;
      }
      // ignore: avoid_dynamic_calls
      await _documentsDirectory!.create(recursive: true);
      debugPrint("✅ Local storage initialized (Mobile - File System)");
    } on MissingPluginException catch (e) {
      // * Catch MissingPluginException - this happens if plugin isn't registered (e.g., on web)
      debugPrint("⚠️ path_provider plugin not registered (this is OK on web): $e");
      debugPrint("💡 Using SharedPreferences as fallback");
      _documentsDirectory = null;
    } catch (e) {
      debugPrint("⚠️ Error initializing local storage: $e");
      // * Don't throw - app can still work with SharedPreferences as fallback
      _documentsDirectory = null;
    }
  }

  /// * Get documents directory - MOBILE ONLY (never called on web)
  Future<dynamic> _getDocumentsDirectoryMobile() async {
    // * Triple-check we're not on web
    if (kIsWeb) {
      debugPrint("❌ ERROR: _getDocumentsDirectoryMobile called on web!");
      return null;
    }
    
    // * Use conditional import - on web this imports stub, on mobile imports real path_provider
    // * But we've already checked kIsWeb, so this is safe
    try {
      // ignore: undefined_prefixed_name
      final result = await path_loader.getApplicationDocumentsDirectory();
      return result;
    } on MissingPluginException catch (e) {
      // * Catch MissingPluginException specifically - this happens if plugin isn't registered
      debugPrint("⚠️ path_provider plugin not available (this is normal on web): $e");
      return null;
    } catch (e) {
      debugPrint("⚠️ Error getting documents directory: $e");
      return null;
    }
  }

  /// * Get documents directory (mobile only)
  dynamic get documentsDir {
    if (_isWeb) return null;
    if (_documentsDirectory == null) {
      throw Exception("LocalStorageService not initialized. Call initialize() first.");
    }
    return _documentsDirectory;
  }

  /// * Get storage file path (mobile only)
  String? _getFilePath(String fileName) {
    if (_isWeb) return null;
    return "${documentsDir!.path}/$fileName";
  }

  /// * Read JSON file
  Future<Map<String, dynamic>> readJsonFile(String fileName) async {
    try {
      if (_isWeb) {
        // * Use SharedPreferences for web
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final String? data = prefs.getString(fileName);
        if (data == null) return {};
        return jsonDecode(data) as Map<String, dynamic>;
      } else {
        final String? filePath = _getFilePath(fileName);
        if (filePath == null) return {};
        // * Use dynamic import for File on non-web
        final file = _createFile(filePath);
        if (file == null || !await _fileExists(file)) {
          return {};
        }
        final String contents = await _readFileContents(file);
        return jsonDecode(contents) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Error reading JSON file: $e");
      return {};
    }
  }

  /// * Write JSON file
  Future<void> writeJsonFile(
    String fileName,
    Map<String, dynamic> data,
  ) async {
    try {
      if (_isWeb) {
        // * Use SharedPreferences for web
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString(fileName, jsonEncode(data));
      } else {
        final String? filePath = _getFilePath(fileName);
        if (filePath == null) throw Exception("File path is null");
        final file = _createFile(filePath);
        if (file == null) throw Exception("Failed to create file");
        await _writeFileContents(file, jsonEncode(data));
      }
    } catch (e) {
      throw Exception("Failed to write file: $e");
    }
  }

  /// * Read list from JSON file
  Future<List<Map<String, dynamic>>> readJsonList(String fileName) async {
    try {
      if (_isWeb) {
        // * Use SharedPreferences for web
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final String? data = prefs.getString(fileName);
        if (data == null) return [];
        final dynamic decoded = jsonDecode(data);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
        return [];
      } else {
        final String? filePath = _getFilePath(fileName);
        if (filePath == null) return [];
        final file = _createFile(filePath);
        if (file == null || !await _fileExists(file)) {
          return [];
        }
        final String contents = await _readFileContents(file);
        final dynamic decoded = jsonDecode(contents);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
        return [];
      }
    } catch (e) {
      debugPrint("Error reading JSON list: $e");
      return [];
    }
  }

  /// * Write list to JSON file
  Future<void> writeJsonList(
    String fileName,
    List<Map<String, dynamic>> data,
  ) async {
    try {
      if (_isWeb) {
        // * Use SharedPreferences for web
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString(fileName, jsonEncode(data));
      } else {
        final String? filePath = _getFilePath(fileName);
        if (filePath == null) throw Exception("File path is null");
        final file = _createFile(filePath);
        if (file == null) throw Exception("Failed to create file");
        await _writeFileContents(file, jsonEncode(data));
      }
    } catch (e) {
      throw Exception("Failed to write file: $e");
    }
  }

  /// * Save image file locally (mobile only - web uses base64)
  Future<String> saveImageFile(dynamic imageFile, String fileName) async {
    try {
      if (_isWeb) {
        // * For web, convert to base64 and store in SharedPreferences
        final List<int> bytes = await imageFile.readAsBytes();
        final String base64 = base64Encode(bytes);
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString("image_$fileName", base64);
        return "image_$fileName"; // * Return key instead of path
      } else {
        final dynamic imagesDir = documentsDir;
        if (imagesDir == null) throw Exception("Documents directory not available");
        // ignore: avoid_dynamic_calls
        final imagesDirectory = _createDirectory("${imagesDir.path}/images");
        if (imagesDirectory != null && !await _directoryExists(imagesDirectory)) {
          await _createDirectoryRecursive(imagesDirectory);
        }

        final destination = _createFile("${imagesDir.path}/images/$fileName");
        if (destination == null) throw Exception("Failed to create destination file");
        await _copyFile(imageFile, destination);

        return "${imagesDir.path}/images/$fileName";
      }
    } catch (e) {
      throw Exception("Failed to save image: $e");
    }
  }

  /// * Get image file (mobile) or base64 data (web)
  dynamic getImageFile(String filePath) {
    try {
      if (_isWeb) {
        // * Web doesn't use File objects, return null
        return null;
      }
      final file = _createFile(filePath);
      if (file != null && _fileExistsSync(file)) {
        return file;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // * Helper methods for file operations (platform-specific)
  dynamic _createFile(String path) {
    if (_isWeb) return null;
    // * Use File directly (conditionally imported - stub on web, real on mobile)
    return File(path);
  }

  dynamic _createDirectory(String path) {
    if (_isWeb) return null;
    // * Use Directory directly (conditionally imported - stub on web, real on mobile)
    return Directory(path);
  }

  Future<bool> _fileExists(dynamic file) async {
    if (_isWeb || file == null) return false;
    // ignore: avoid_dynamic_calls
    return await file.exists();
  }

  bool _fileExistsSync(dynamic file) {
    if (_isWeb || file == null) return false;
    // ignore: avoid_dynamic_calls
    return file.existsSync();
  }

  Future<bool> _directoryExists(dynamic directory) async {
    if (_isWeb || directory == null) return false;
    // ignore: avoid_dynamic_calls
    return await directory.exists();
  }

  Future<void> _createDirectoryRecursive(dynamic directory) async {
    if (_isWeb || directory == null) return;
    // ignore: avoid_dynamic_calls
    await directory.create(recursive: true);
  }

  Future<String> _readFileContents(dynamic file) async {
    if (_isWeb || file == null) throw Exception("File is null");
    // ignore: avoid_dynamic_calls
    return await file.readAsString();
  }

  Future<void> _writeFileContents(dynamic file, String contents) async {
    if (_isWeb || file == null) throw Exception("File is null");
    // ignore: avoid_dynamic_calls
    await file.writeAsString(contents);
  }

  Future<void> _copyFile(dynamic source, dynamic destination) async {
    if (_isWeb || source == null || destination == null) {
      throw Exception("File operations not supported on web");
    }
    // ignore: avoid_dynamic_calls
    await source.copy(destination.path);
  }

  /// * Get image as base64 (for web)
  Future<String?> getImageBase64(String key) async {
    if (!_isWeb) return null;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (e) {
      return null;
    }
  }

  /// * Save to SharedPreferences
  Future<void> saveString(String key, String value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  /// * Read from SharedPreferences
  Future<String?> readString(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  /// * Remove from SharedPreferences
  Future<void> remove(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}

