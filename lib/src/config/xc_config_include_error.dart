// Port of xcodeproj exception conventions.
/// Thrown when an xcconfig #include cannot be resolved (missing file or cycle).
class XcConfigIncludeError implements Exception {
  final String message;
  const XcConfigIncludeError(this.message);
  @override
  String toString() => '[!] $message';
}
