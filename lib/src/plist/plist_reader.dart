// Unified plist reader dispatching to ASCII, XML, or binary parsers.
// Per , binary write is deferred to v2 — this file is read-only for binary.

import 'dart:io';
import 'dart:typed_data';

import 'package:propertylistserialization/propertylistserialization.dart';

import 'ascii_plist_reader.dart';
import 'plist_format.dart';
import 'plist_parse_error.dart';

/// Unified plist reader. Dispatches to ASCII, XML, or binary parser based
/// on content prefix. Port of Ruby Xcodeproj::Plist.
/// Usage:
/// ```dart
/// final map = PlistReader.readFromPath('path/to/project.pbxproj');
/// final map = PlistReader.readFromString(asciiPlistString);
/// final map = PlistReader.readFromBytes(binaryPlistBytes);
/// ```
class PlistReader {
  PlistReader._();

  /// Reads a plist from disk. Auto-detects format from content prefix.
  /// Throws [PlistParseError] if the file does not exist, contains git merge
  /// conflict markers, or cannot be parsed.
  static Map<String, dynamic> readFromPath(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw PlistParseError('Plist file not found: $path');
    }
    // Read raw bytes first to detect binary plist magic without UTF-8 decode.
    final bytes = file.readAsBytesSync();
    if (_isBinaryPlist(bytes)) {
      return readFromBytes(bytes);
    }
    // ASCII and XML plists are text — decode as UTF-8.
    final contents = String.fromCharCodes(bytes);
    return readFromString(contents);
  }

  /// Reads a plist from an in-memory string (ASCII or XML).
  /// Throws [PlistParseError] if the string contains git merge conflict markers
  /// or cannot be parsed as a valid plist.
  static Map<String, dynamic> readFromString(String contents) {
    if (_isInConflict(contents)) {
      throw const PlistParseError(
        'File contains git merge conflict markers (<<<<<<<, =======, >>>>>>>)',
      );
    }
    final format = AsciiPlistReader.detectFormat(contents);
    switch (format) {
      case PlistFormat.ascii:
        return AsciiPlistReader(contents).parse();
      case PlistFormat.xml:
        try {
          final result = PropertyListSerialization.propertyListWithString(
            contents,
          );
          return _coerceMap(result);
        } on PropertyListReadStreamException catch (e) {
          throw PlistParseError('Failed to parse XML plist: $e');
        }
      case PlistFormat.binary:
        // String content cannot be binary; if detectFormat says binary,
        // the caller should have used readFromBytes.
        throw const PlistParseError(
          'Binary plist detected in string input — use readFromBytes',
        );
    }
  }

  /// Reads a binary plist from raw bytes.
  /// Throws [PlistParseError] if [bytes] do not start with the `bplist` magic
  /// or the binary plist data is malformed.
  static Map<String, dynamic> readFromBytes(List<int> bytes) {
    if (!_isBinaryPlist(bytes)) {
      throw const PlistParseError(
        'Bytes do not start with bplist magic (62 70 6c 69 73 74)',
      );
    }
    // propertylistserialization takes ByteData, not Uint8List.
    final uint8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final byteData = uint8.buffer.asByteData(
      uint8.offsetInBytes,
      uint8.lengthInBytes,
    );
    try {
      final result = PropertyListSerialization.propertyListWithData(byteData);
      return _coerceMap(result);
    } on PropertyListReadStreamException catch (e) {
      throw PlistParseError('Failed to parse binary plist: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  // Port of Ruby Xcodeproj::Plist.file_in_conflict?.
  // Pattern: <<<<<<< (7 x <) ... ======= (7 x =) ... >>>>>>> (7 x >)
  // Not preceded by additional < or = or > (negative lookahead).
  static final RegExp _conflictPattern = RegExp(
    r'^<{7}(?!<)[\s\S]*?^={7}(?!=)[\s\S]*?^>{7}(?!>)',
    multiLine: true,
  );

  static bool _isInConflict(String contents) =>
      _conflictPattern.hasMatch(contents);

  // Binary plist magic bytes: 'bplist' = 0x62 0x70 0x6c 0x69 0x73 0x74
  static bool _isBinaryPlist(List<int> bytes) {
    if (bytes.length < 6) return false;
    return bytes[0] == 0x62 && // b
        bytes[1] == 0x70 && // p
        bytes[2] == 0x6c && // l
        bytes[3] == 0x69 && // i
        bytes[4] == 0x73 && // s
        bytes[5] == 0x74; // t
  }

  // propertylistserialization returns Map<String, Object>, not Map<String, dynamic>.
  // Coerce to Map<String, dynamic> so consumers receive a uniform type.
  // Threat Integrity — explicit coercion prevents runtime type errors.
  // recursively coerce nested Maps and Lists so that deeply nested
  // dicts are also Map<String, dynamic>, not Map<String, Object>.
  static dynamic _coerceValue(Object? v) {
    if (v is Map) {
      return v.map<String, dynamic>(
        (k, val) => MapEntry(k.toString(), _coerceValue(val)),
      );
    }
    if (v is List) {
      return v.map(_coerceValue).toList();
    }
    return v;
  }

  static Map<String, dynamic> _coerceMap(Object value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map<String, dynamic>(
        (k, v) => MapEntry(k.toString(), _coerceValue(v)),
      );
    }
    throw PlistParseError(
      'Root plist value is not a dictionary (got ${value.runtimeType})',
    );
  }
}
