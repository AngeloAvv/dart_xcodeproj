/// Bidirectional snake_case ↔ camelCase conversion with caches.
/// Port of xcodeproj's CaseConverter.
class CaseConverter {
  CaseConverter._(); // prevent instantiation — all static

  // three independent caches, one per direction.
  static final Map<String, String> _toLowerCache = <String, String>{};
  static final Map<String, String> _toUpperCache = <String, String>{};
  static final Map<String, String> _toSnakeCache = <String, String>{};

  /// Table of known exceptions where the algorithmic snake_case→camelCase
  /// conversion produces an incorrect result.
  /// these are maintained here rather than as individual if-checks so
  /// that future maintainers can add new exceptions without understanding the
  /// algorithm. The root cause is that _capitalizeFirst lowercases each segment
  /// entirely, turning acronyms like 'ID' into 'Id'. Exceptions override that.
  /// Extend this table when new mismatches are discovered against real .pbxproj
  /// files (compare output against Xcode's own key names).
  static const Map<String, String> _toPlistKeyExceptions = {
    'remote_global_id_string': 'remoteGlobalIDString',
    // Add further exceptions here as discovered.
  };

  /// snake_case → lowerCamelCase. Equivalent to Ruby convert_to_plist(name, :lower).
  /// Checks [_toPlistKeyExceptions] first (), then falls back to the
  /// algorithmic conversion via [_camelize].
  static String toPlistKey(String snakeCase) {
    final exception = _toPlistKeyExceptions[snakeCase];
    if (exception != null) return exception;
    return _toLowerCache[snakeCase] ??= _camelize(snakeCase, upperFirst: false);
  }

  /// snake_case → UpperCamelCase. Equivalent to Ruby convert_to_plist(name) (no :lower).
  static String toPlistKeyUpperFirst(String snakeCase) {
    return _toUpperCache[snakeCase] ??= _camelize(snakeCase, upperFirst: true);
  }

  /// camelCase → snake_case. Equivalent to Ruby convert_to_ruby(name).
  /// Two-pass underscore algorithm — order of passes matters.
  static String toSnakeCase(String camelCase) {
    return _toSnakeCache[camelCase] ??= _underscore(camelCase);
  }

  /// Clears all three caches. Test-isolation helper only.
  static void clearCaches() {
    _toLowerCache.clear();
    _toUpperCache.clear();
    _toSnakeCache.clear();
  }

  // Port of (ActiveSupport camelize).
  // Splits on '_', capitalises each subsequent word, joins without separator.
  static String _camelize(String term, {required bool upperFirst}) {
    if (term.isEmpty) return term;
    final parts = term.split('_');
    final first = upperFirst
        ? _capitalizeFirst(parts[0])
        : parts[0].toLowerCase();
    final rest = parts.skip(1).map(_capitalizeFirst);
    return [first, ...rest].join();
  }

  // Capitalise first letter, lower-case remainder.
  static String _capitalizeFirst(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  // Port of (ActiveSupport underscore).
  // ORDER MATTERS
  // Pass 1: ([A-Z\d]+)([A-Z][a-z]) → \1_\2 (IDString → ID_String)
  // Pass 2: ([a-z\d])([A-Z]) → \1_\2 (camelCase → camel_Case)
  // Then: hyphen → underscore, lowercase entire string.
  // NOTE: Dart's replaceAllMapped must be used (not replaceAll with string
  // replacement) because Dart does NOT support capture group backreferences
  // in String replacement arguments to replaceAll.
  static String _underscore(String word) {
    if (!word.contains(RegExp(r'[A-Z\-]'))) return word;
    return word
        .replaceAllMapped(
          RegExp(r'([A-Z\d]+)([A-Z][a-z])'),
          (m) => '${m[1]}_${m[2]}',
        )
        .replaceAllMapped(RegExp(r'([a-z\d])([A-Z])'), (m) => '${m[1]}_${m[2]}')
        .replaceAll('-', '_')
        .toLowerCase();
  }
}
