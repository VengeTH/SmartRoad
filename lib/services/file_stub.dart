// * Stub for File and Directory on web
// * This file is used when dart.library.html is available

/// * Stub File class for web
class File {
  final String path;
  File(this.path);
  Future<bool> exists() async => false;
  bool existsSync() => false;
  Future<String> readAsString() async => throw UnsupportedError("File operations not supported on web");
  Future<void> writeAsString(String contents) async => throw UnsupportedError("File operations not supported on web");
  Future<List<int>> readAsBytes() async => throw UnsupportedError("File operations not supported on web");
  Future<File> copy(String newPath) async => throw UnsupportedError("File operations not supported on web");
}

/// * Stub Directory class for web
class Directory {
  final String path;
  Directory(this.path);
  Future<bool> exists() async => false;
  bool existsSync() => false;
  Future<Directory> create({bool recursive = false}) async => throw UnsupportedError("Directory operations not supported on web");
}

