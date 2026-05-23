import 'dart:convert';
// import only Random to prevent accidental use of Random() (insecure PRNG).
// UUID generation MUST use Random.secure() exclusively.
import 'dart:math' show Random;

import 'package:crypto/crypto.dart';

/// UUID generation utilities for Xcode project object identifiers.
/// Xcode uses two UUID formats:
/// - Random: 24-char uppercase hex, equivalent to Ruby `SecureRandom.hex(12).upcase`
/// - Deterministic: 32-char uppercase hex (full MD5), equivalent to Ruby `Digest::MD5.hexdigest(path).upcase`
/// See (random) and (deterministic).
class UuidGenerator {
  UuidGenerator._();

  static final Random _random = Random.secure();

  /// Validates the 24-char uppercase hex format used by Xcode for random object UUIDs.
  /// Returns true only for exactly 24 uppercase hexadecimal characters.
  /// Rejects RFC4122 UUIDs (which contain hyphens), lowercase, wrong-length strings,
  /// and strings with non-hex characters.
  static final RegExp _uuidPattern = RegExp(r'^[0-9A-F]{24}$');

  /// Returns a random 24-char uppercase hex UUID.
  /// Equivalent to Ruby `SecureRandom.hex(12).upcase`:
  /// generates 12 cryptographically random bytes and encodes them as 24 hex chars.
  static String generate() {
    final bytes = List<int>.generate(12, (_) => _random.nextInt(256));
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  /// Returns a deterministic UUID derived from [structuralPath] via MD5.
  /// Equivalent to Ruby `Digest::MD5.hexdigest(structuralPath).upcase`.
  /// Returns the full 32-char uppercase hex MD5 digest — matching Ruby gem behavior
  /// where `predictabilizeUuids()` replaces random UUIDs with MD5-based identifiers.
  /// Verified test vectors (per and Ruby reference):
  /// - `''` → `'D41D8CD98F00B204E9800998ECF8427E'`
  /// - `'hello'` → `'5D41402ABC4B2A76B9719D911017C592'`
  /// - `'test'` → `'098F6BCD4621D373CADE4E832627B4F6'`
  static String generateDeterministic(String structuralPath) {
    final digest = md5.convert(utf8.encode(structuralPath));
    return digest.toString().toUpperCase();
  }

  /// Returns true if [uuid] is a valid 24-char uppercase hex Xcode object UUID.
  /// Accepts only exactly 24 uppercase hex characters [0-9A-F].
  /// Rejects: lowercase, hyphens (RFC4122 format), wrong length, non-hex chars.
  static bool isValid(String uuid) => _uuidPattern.hasMatch(uuid);

  /// Converts a nested object into a deterministic string path for use as MD5 input:
  /// - If [depth] == 0: returns `'|'` (cutoff sentinel).
  /// - If [object] is a [Map]: sorts keys lexicographically, formats as `'key:value,'`
  /// for each entry, values are recursed at `depth - 1`.
  /// - If [object] is a [List]: joins elements with `','` (no trailing comma),
  /// elements are recursed at `depth - 1`.
  /// - Otherwise: returns `object.toString()`.
  /// Used by `predictabilizeUuids` `predictabilizeUuids()` to produce structural paths for MD5 seeding.
  static String treeHashToPath(dynamic object, [int depth = 4]) {
    if (depth == 0) return '|';
    if (object is Map) {
      final sb = StringBuffer();
      final sortedKeys = object.keys.toList()
        ..sort((a, b) => a.toString().compareTo(b.toString()));
      for (final key in sortedKeys) {
        sb.write('$key:${treeHashToPath(object[key], depth - 1)},');
      }
      return sb.toString();
    } else if (object is List) {
      return object.map((v) => treeHashToPath(v, depth - 1)).join(',');
    } else {
      return object.toString();
    }
  }
}
