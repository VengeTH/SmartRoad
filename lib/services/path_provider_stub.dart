// * Stub file for path_provider on web
// * This file is only used when path_provider is not available (web)

/// * Stub class to prevent import errors on web
class StubDirectory {
  String path = "";
  Future<void> create({bool recursive = false}) async {}
  Future<bool> exists() async => false;
}

/// * Stub function for web - returns null instead of throwing
/// * This prevents the plugin from being called
Future<StubDirectory?> getApplicationDocumentsDirectory() async {
  // * Return null on web - this will be checked before use
  return null;
}

