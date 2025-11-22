import "package:flutter_dotenv/flutter_dotenv.dart";
import "package:supabase_flutter/supabase_flutter.dart";

/// * Supabase configuration and initialization
class SupabaseConfig {
  SupabaseConfig._();

  /// * Initialize Supabase with environment variables
  static Future<void> initialize() async {
    await dotenv.load(fileName: ".env");

    final String supabaseUrl = dotenv.env["SUPABASE_URL"] ?? "";
    final String supabaseAnonKey = dotenv.env["SUPABASE_ANON_KEY"] ?? "";

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception(
        "SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env file",
      );
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  /// * Get Supabase client instance
  static SupabaseClient get client => Supabase.instance.client;
}

