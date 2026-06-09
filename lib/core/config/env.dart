/// * Environment configuration loader
/// Loads environment variables from .env file or platform environment
class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
  
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  
  /// * Whether the API configuration is present
  static bool get hasApiConfig => apiBaseUrl.isNotEmpty;
  
  /// * Validates that required environment variables are set
  static bool validate() {
    return hasApiConfig;
  }
}

