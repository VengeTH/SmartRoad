// * Helper file for path_provider - mobile version
// * This file is used when dart.library.io is available (mobile platforms)

import "package:path_provider/path_provider.dart" as path_provider;

/// * Get application documents directory (mobile only)
Future<dynamic> getDocumentsDirectory() async {
  return await path_provider.getApplicationDocumentsDirectory();
}

