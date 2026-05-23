// Port of Nanaimo::Reader::ParseError

/// Exception thrown when parsing a malformed ASCII plist fails.
class PlistParseError implements Exception {
  final String message;
  final int line;
  final int column;

  const PlistParseError(this.message, [this.line = 0, this.column = 0]);

  @override
  String toString() => '[!] $message at line $line, column $column';
}
