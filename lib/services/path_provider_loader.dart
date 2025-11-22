// * Path provider loader for mobile platforms
// * This file is conditionally imported

import "package:path_provider/path_provider.dart" as path_provider;

/// * Get application documents directory
Future<dynamic> getApplicationDocumentsDirectory() async {
  return await path_provider.getApplicationDocumentsDirectory();
}

