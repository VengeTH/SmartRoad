/// * Sticker Verifier Service
/// * Uses Google Gemini AI to verify if uploaded images are valid HOA stickers
import "dart:io";
import "dart:typed_data";
import "dart:convert";
import "package:dio/dio.dart";
import "../core/config/env.dart";

class StickerVerifierService {
  static const String _modelName = "gemini-2.5-flash";
  static const String _baseUrl = "https://generativelanguage.googleapis.com/v1beta";
  
  /// * Verify if an image contains a valid HOA sticker
  /// * 
  /// * [imageFile] - The image file to verify (can be null if using bytes)
  /// * [hoaName] - The name of the HOA (e.g., "BF Resort")
  /// * [imageBytes] - Optional image bytes (for web compatibility)
  /// * 
  /// * Returns true if AI confirms the image looks like a sticker, false otherwise
  Future<bool> verifyStickerImage(
    File? imageFile,
    String hoaName, {
    Uint8List? imageBytes,
  }) async {
    try {
      // * Get API key from environment
      final apiKey = Env.geminiApiKey;
      if (apiKey.isEmpty) {
        throw Exception("GEMINI_API_KEY not configured. Please set it in your environment.");
      }
      
      // * Read image bytes and convert to base64
      final Uint8List bytes;
      if (imageBytes != null) {
        bytes = imageBytes;
      } else if (imageFile != null) {
        bytes = await imageFile.readAsBytes();
      } else {
        throw Exception("Either imageFile or imageBytes must be provided");
      }
      
      final base64Image = base64Encode(bytes);
      
      // * Create prompt
      final prompt = "Look at this image. Does it contain a car sticker or pass for '$hoaName'? Answer only 'YES' or 'NO'. If it's too blurry or not a sticker, answer 'NO'.";
      
      // * Prepare request body
      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text": prompt
              },
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Image
                }
              }
            ]
          }
        ]
      };
      
      // * Make API request using Dio
      final dio = Dio();
      final url = "$_baseUrl/models/$_modelName:generateContent?key=$apiKey";
      final response = await dio.post(
        url,
        data: requestBody,
        options: Options(
          headers: {
            "Content-Type": "application/json",
          },
        ),
      );
      
      if (response.statusCode != 200) {
        print("Error verifying sticker: ${response.statusCode} - ${response.data}");
        return false;
      }
      
      // * Parse response
      final responseData = response.data as Map<String, dynamic>;
      final candidates = responseData["candidates"] as List<dynamic>?;
      
      if (candidates == null || candidates.isEmpty) {
        return false;
      }
      
      final firstCandidate = candidates[0] as Map<String, dynamic>;
      final content = firstCandidate["content"] as Map<String, dynamic>?;
      final parts = content?["parts"] as List<dynamic>?;
      
      if (parts == null || parts.isEmpty) {
        return false;
      }
      
      final textPart = parts[0] as Map<String, dynamic>?;
      final responseText = (textPart?["text"] as String? ?? "").trim().toUpperCase();
      
      // * Check if response is "YES"
      return responseText == "YES";
    } catch (e) {
      // * On any error, return false (fail-safe)
      print("Error verifying sticker image: $e");
      return false;
    }
  }
}

