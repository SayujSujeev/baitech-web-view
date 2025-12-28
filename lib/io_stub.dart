// Stub file for web platform - File operations are not supported on web
class File {
  final String path;
  File(this.path);
  Future<bool> exists() => throw UnsupportedError('File operations not supported on web');
  Future<List<int>> readAsBytes() => throw UnsupportedError('File operations not supported on web');
  Future<File> writeAsBytes(List<int> bytes, {bool flush = false}) => throw UnsupportedError('File operations not supported on web');
  Future<File> copy(String newPath) => throw UnsupportedError('File operations not supported on web');
  Future<void> delete() => throw UnsupportedError('File operations not supported on web');
  Uri get uri => throw UnsupportedError('File operations not supported on web');
}

