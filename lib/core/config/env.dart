/// * Environment configuration loader
/// Loads environment variables from .env file or platform environment
class Env {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  
  static const String storageBucketName = String.fromEnvironment(
    'STORAGE_BUCKET_NAME',
    defaultValue: 'hazard-images',
  );
  
  /// * Validates that required environment variables are set
  static bool validate() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      return false;
    }
    return true;
  }
}

