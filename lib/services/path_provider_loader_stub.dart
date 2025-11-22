// * Stub for path_provider on web
// * This file is used when dart.library.html is available (web platform)

/// * Stub function - returns null immediately without any plugin calls
/// * This prevents the path_provider plugin from being registered on web
/// * IMPORTANT: This should NEVER be called on web due to kIsWeb check in initialize()
Future<dynamic> getApplicationDocumentsDirectory() async {
  // * Return null immediately - no plugin calls on web
  // * This function should only be called if kIsWeb check fails (which shouldn't happen)
  // * If this is called, it means the conditional import isn't working correctly
  return null;
}

