/// * App configuration - determines if using local storage or Supabase
class AppConfig {
  AppConfig._();

  /// * Use local storage instead of Supabase
  /// * Set to true to use local file storage (no database required)
  /// * Set to false to use Supabase (requires database setup)
  static const bool useLocalStorage = true;

  /// * Get storage mode description
  static String get storageMode => useLocalStorage ? "Local Storage" : "Supabase";
}

