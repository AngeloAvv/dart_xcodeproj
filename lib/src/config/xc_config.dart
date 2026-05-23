// DEVIATION from Ruby: XcConfig.open() eagerly resolves #include directives
// at load time (Ruby defers to to_hash). This is intentional
// missing includes throw XcConfigIncludeError immediately, and circular
// includes are detected via a visited-path Set.

import 'dart:io';

import 'package:path/path.dart' as p;

import 'other_linker_flags_parser.dart';
import 'xc_config_include_error.dart';

/// KEY pattern: `[^=\[]+` plus optional conditional subscripts `\[[^\]]*\]`,
/// then `=`, then value. Matches Ruby KEY_VALUE_PATTERN.
final RegExp _kKeyValuePattern = RegExp(
  r'^\s*([^=\[\s]+(?:\[[^\]]*\])*)\s*=\s*(.*)$',
);

/// `#include "path"` or `#include? "path"` (optional `?`).
final RegExp _kIncludePattern = RegExp(r'^\s*#include\??\s*"([^"]+)"');

/// Strips trailing `//` comments from a raw xcconfig line in a quote-aware
/// manner. Unlike a plain [String.indexOf], this correctly preserves values
/// that contain `://` (e.g. `BASE_URL = https://api.example.com`).
/// Backslash escape sequences are not supported inside xcconfig quotes, so
/// only quote-open / quote-close state is tracked.
String _stripComment(String rawLine) {
  var inSingleQuote = false;
  var inDoubleQuote = false;
  for (var i = 0; i < rawLine.length - 1; i++) {
    final c = rawLine[i];
    if (c == "'" && !inDoubleQuote) inSingleQuote = !inSingleQuote;
    if (c == '"' && !inSingleQuote) inDoubleQuote = !inDoubleQuote;
    if (!inSingleQuote && !inDoubleQuote && c == '/' && rawLine[i + 1] == '/') {
      return rawLine.substring(0, i);
    }
  }
  return rawLine;
}

/// Holds the data for an Xcode build settings file (`.xcconfig`) and provides
/// support for serialization, eager `#include` resolution, and merging.
/// Port of Ruby `Xcodeproj::Config`.
class XcConfig {
  /// Absolute normalized path to the `.xcconfig` file on disk.
  final String path;

  /// Build setting key → value pairs (excluding `OTHER_LDFLAGS` modifier sets).
  /// After [open], this map includes settings from resolved `#include` files
  /// where the including file wins on key conflicts.
  final Map<String, String> attributes = <String, String>{};

  /// Raw `#include` paths in declaration order (as they appear in the file).
  final List<String> includes = <String>[];

  // OTHER_LDFLAGS modifier sets — kept separate to enable deduplication.
  final Set<String> frameworks = <String>{};
  final Set<String> weakFrameworks = <String>{};
  final Set<String> libraries = <String>{};
  final Set<String> argFiles = <String>{};
  final Set<String> forceLoad = <String>{};
  final Set<String> simpleOtherLdflags = <String>{};

  XcConfig._(this.path);

  // ---------------------------------------------------------------------------
  // Factories
  // ---------------------------------------------------------------------------

  /// Creates an empty xcconfig at [path]. Does NOT write to disk.
  static XcConfig create(String path) => XcConfig._(p.normalize(path));

  /// Opens an existing `.xcconfig`, eagerly resolving all `#include`
  /// directives.
  /// Throws [XcConfigIncludeError] if an included file is missing or if a
  /// circular `#include` chain is detected.
  static Future<XcConfig> open(String path) async {
    final normalized = p.normalize(path);
    final config = XcConfig._(normalized);
    await config._loadFromFile(normalized, <String>{}, <String>[]);
    return config;
  }

  // ---------------------------------------------------------------------------
  // Private loading
  // ---------------------------------------------------------------------------

  /// [visitedSet] enables O(1) cycle detection; [visitedOrder] preserves the
  /// deterministic insertion order required for a human-readable error message.
  Future<void> _loadFromFile(
    String absPath,
    Set<String> visitedSet,
    List<String> visitedOrder,
  ) async {
    final canonical = p.canonicalize(absPath);
    if (visitedSet.contains(canonical)) {
      // Build cycle path in deterministic insertion order.
      final cycle = [...visitedOrder, canonical].join(' -> ');
      throw XcConfigIncludeError('Circular #include detected: $cycle');
    }

    final nextSet = <String>{...visitedSet, canonical};
    final nextOrder = <String>[...visitedOrder, canonical];
    // Use async readAsString and catch OS exceptions to avoid both the
    // synchronous existsSync() blocking call and the TOCTOU race between an
    // existence check and the subsequent read.
    final content = await File(absPath).readAsString().catchError((_) {
      throw XcConfigIncludeError('xcconfig file not found: $absPath');
    });
    final dir = p.dirname(absPath);

    for (final rawLine in content.split('\n')) {
      // Strip comments — retain text before `//`, quote-aware.
      final line = _stripComment(rawLine).trim();
      if (line.isEmpty) continue;

      final incMatch = _kIncludePattern.firstMatch(line);
      if (incMatch != null) {
        final rawIncPath = incMatch.group(1)!;
        final isOptional = line.trimLeft().startsWith('#include?');
        final normalizedInc = _normalizedXcconfigPath(rawIncPath);
        includes.add(rawIncPath);
        final resolvedPath = p.normalize(p.join(dir, normalizedInc));
        if (isOptional && !File(resolvedPath).existsSync()) continue;
        await _loadFromFile(resolvedPath, nextSet, nextOrder);
        continue;
      }

      final kv = _kKeyValuePattern.firstMatch(line);
      if (kv == null) continue;

      final key = kv.group(1)!.trim();
      final value = kv.group(2)!.trim();

      if (key == 'OTHER_LDFLAGS') {
        final parsed = OtherLinkerFlagsParser.parse(value);
        frameworks.addAll(parsed.frameworks);
        weakFrameworks.addAll(parsed.weakFrameworks);
        libraries.addAll(parsed.libraries);
        argFiles.addAll(parsed.argFiles);
        forceLoad.addAll(parsed.forceLoad);
        simpleOtherLdflags.addAll(parsed.simple);
        // Do NOT store in attributes — toS() always synthesizes from modifier
        // sets via _serializeOtherLdflags(). This preserves round-trip fidelity
        // consistent with the Ruby behavior.
        continue;
      }

      // Including config wins on conflict.
      // Lines are processed in order: included file first, then the including
      // file's own lines. Since the including file's lines are parsed AFTER
      // _loadFromFile returns, they naturally overwrite the included values.
      attributes[key] = value;
    }
  }

  /// append `.xcconfig` extension if missing (matching Ruby
  /// normalized_xcconfig_path from).
  static String _normalizedXcconfigPath(String includePath) {
    if (p.extension(includePath) == '.xcconfig') return includePath;
    return '$includePath.xcconfig';
  }

  // ---------------------------------------------------------------------------
  // Serialization ()
  // ---------------------------------------------------------------------------

  /// Writes the serialized config to [path], creating parent directories.
  /// Port of Ruby `Config#save_as`.
  Future<void> save() async {
    await Directory(p.dirname(path)).create(recursive: true);
    await File(path).writeAsString(toS());
  }

  /// Returns the serialized string representation.
  /// Format:
  /// 1. `#include` lines in insertion order.
  /// 2. KEY = VALUE lines sorted alphabetically by key.
  /// `OTHER_LDFLAGS` is reconstructed from the modifier sets.
  /// Port of Ruby `Config#to_s`.
  String toS() {
    final buf = StringBuffer();

    // #include lines first (unsorted, insertion order).
    // Serialize the raw path as stored — extension normalization is only for
    // filesystem resolution at load time, not for round-trip output.
    for (final inc in includes) {
      buf.writeln('#include "$inc"');
    }

    // Collect all keys to serialize — attributes + OTHER_LDFLAGS if non-empty
    final allAttributes = Map<String, String>.from(attributes);

    final hasOtherLdflags =
        frameworks.isNotEmpty ||
        weakFrameworks.isNotEmpty ||
        libraries.isNotEmpty ||
        argFiles.isNotEmpty ||
        forceLoad.isNotEmpty ||
        simpleOtherLdflags.isNotEmpty;

    if (hasOtherLdflags) {
      // OTHER_LDFLAGS is never stored in attributes (skipped during parse);
      // inject a placeholder so it appears in the sorted key list and is
      // serialized via _serializeOtherLdflags().
      allAttributes['OTHER_LDFLAGS'] = '';
    }

    final keys = allAttributes.keys.toList()..sort();
    for (final k in keys) {
      if (k == 'OTHER_LDFLAGS') {
        final serialized = _serializeOtherLdflags();
        buf.writeln('$k = $serialized'.trimRight());
      } else {
        buf.writeln('$k = ${allAttributes[k]!}'.trimRight());
      }
    }

    return buf.toString();
  }

  /// Serializes the OTHER_LDFLAGS modifier sets into a single string value.
  /// Ruby to_hash ordering:
  /// simple → libraries → frameworks → weak_frameworks → arg_files → force_load
  /// - `-force_load` uses space before path, no quotes: `-force_load path`
  /// - All others use no space + quotes: `-framework "Name"`, `-l"lib"`, `@"file"`
  String _serializeOtherLdflags() {
    final parts = <String>[];
    for (final s in ([...simpleOtherLdflags]..sort())) {
      parts.add(s);
    }
    for (final l in ([...libraries]..sort())) {
      parts.add('-l"$l"');
    }
    for (final f in ([...frameworks]..sort())) {
      parts.add('-framework "$f"');
    }
    for (final f in ([...weakFrameworks]..sort())) {
      parts.add('-weak_framework "$f"');
    }
    for (final a in ([...argFiles]..sort())) {
      parts.add('@"$a"');
    }
    for (final f in ([...forceLoad]..sort())) {
      parts.add('-force_load $f');
    }
    return parts.join(' ');
  }

  // ---------------------------------------------------------------------------
  // Merging ()
  // ---------------------------------------------------------------------------

  /// Returns a new [XcConfig] with the data of the receiver merged with [other].
  /// Rules:
  /// - Keys present in `this` are NOT overwritten (receiver wins).
  /// - New keys from [other] are added.
  /// - String values for shared keys: receiver wins unconditionally (no concatenation).
  /// - ALL modifier sets are union-merged (Set semantics guarantee deduplication).
  /// - This method is non-mutating: the original receiver is unchanged.
  /// Port of Ruby `Config#merge` / `merge_attributes!`.
  /// [targetPath] overrides the path of the returned config. When omitted the
  /// receiver's own path is used. Provide [targetPath] when the merged config
  /// will be saved at a different location.
  XcConfig merge(XcConfig other, {String? targetPath}) {
    final result = XcConfig._(targetPath ?? path);

    // Copy receiver state
    result.attributes.addAll(attributes);
    result.includes.addAll(includes);
    result.frameworks.addAll(frameworks);
    result.weakFrameworks.addAll(weakFrameworks);
    result.libraries.addAll(libraries);
    result.argFiles.addAll(argFiles);
    result.forceLoad.addAll(forceLoad);
    result.simpleOtherLdflags.addAll(simpleOtherLdflags);

    // Merge other's attributes: receiver wins on key conflict.
    // OTHER_LDFLAGS is never in attributes (always in modifier sets); all
    // other keys use receiver-wins semantics unconditionally.
    for (final entry in other.attributes.entries) {
      if (!result.attributes.containsKey(entry.key)) {
        result.attributes[entry.key] = entry.value;
      }
      // else: receiver wins — do not overwrite
    }

    // Union-merge modifier sets (Set deduplicates automatically)
    result.frameworks.addAll(other.frameworks);
    result.weakFrameworks.addAll(other.weakFrameworks);
    result.libraries.addAll(other.libraries);
    result.argFiles.addAll(other.argFiles);
    result.forceLoad.addAll(other.forceLoad);
    result.simpleOtherLdflags.addAll(other.simpleOtherLdflags);

    // Merge includes (preserve insertion order, no duplicates)
    for (final inc in other.includes) {
      if (!result.includes.contains(inc)) result.includes.add(inc);
    }

    return result;
  }
}
