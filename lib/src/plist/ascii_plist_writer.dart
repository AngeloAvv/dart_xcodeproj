// Transforms Map<String, dynamic> into Apple ASCII plist text.
// Key design notes:
// - Always emits `// !$*UTF8*$!\n` as the first 14 bytes
// - PBXBuildFile and PBXFileReference use flat (single-line) format
// - All other ISAs use pretty (multi-line, tab-indented) format
// - Objects block is grouped by ISA with section comments
// - Within each ISA group, UUIDs sort lexicographically
// - Within each object dict, `isa` key sorts first
// - Indentation uses TAB characters (\t), NOT spaces
// - Annotations (/* ... */) are reconstructed from the objects graph

import 'unicode.dart';

/// Serializes a parsed plist [Map] back to Apple ASCII plist text.
/// Port of [Nanaimo::Writer] + [Nanaimo::Writer::PBXProjWriter]
/// Usage:
/// ```dart
/// final text = AsciiPlistWriter().write(parsedMap);
/// ```
class AsciiPlistWriter {
  /// The magic comment that denotes a UTF8-encoded plist.
  /// Port of Nanaimo::Writer::UTF8.
  /// Exactly 14 bytes: / / space ! $ * U T F 8 * $ ! \n
  // ignore: prefer_single_quotes
  static const _utf8Magic = '// !\$*UTF8*\$!\n';

  final StringBuffer _out = StringBuffer();
  int _indent = 0;

  /// Whether to emit newlines after dict entries, array elements, etc.
  /// Port of @newlines.
  /// Set to false inside flat-mode dictionaries (PBXBuildFile, PBXFileReference).
  bool _newlines = true;

  /// The top-level `objects` map, captured in [write] for annotation lookups.
  /// Port of the objects graph that Nanaimo nodes carry as .annotation.
  late Map<String, dynamic> _objects;

  /// The `rootObject` UUID, captured for the hard-coded "Project object" annotation.
  String? _rootObjectUuid;

  /// Cache of PBXBuildFile UUID → annotation string.
  /// Annotation format: "{fileRef name/path} in {buildPhase name}".
  /// Built once in [write] by scanning all build phase `files` arrays.
  final Map<String, String> _buildFileAnnotations = {};

  /// Cache of XCConfigurationList UUID → annotation string.
  /// Annotation format: "Build configuration list for {ownerType} \"{ownerName}\"".
  /// Built once in [write] by scanning PBXProject + PBXNativeTarget/PBXAggregateTarget
  /// objects for their `buildConfigurationList` field.
  final Map<String, String> _configListAnnotations = {};

  /// Serialize a parsed plist Map back to ASCII plist text.
  /// Port of Writer#write:
  /// ```ruby
  /// def write
  /// write_utf8
  /// write_object(@plist.root_object)
  /// write_newline
  /// end
  /// ```
  /// First 14 bytes of the result are always `// !$*UTF8*$!\n`.
  String write(Map<String, dynamic> plist) {
    _objects = (plist['objects'] as Map?)?.cast<String, dynamic>() ?? const {};
    _rootObjectUuid = plist['rootObject'] as String?;
    _out.clear();
    _buildFileAnnotations.clear();
    _configListAnnotations.clear();
    _indent = 0;
    _newlines = true;
    _buildAnnotationCaches();
    _out.write(_utf8Magic);
    _writeRootDictionary(plist);
    _out.write('\n');
    return _out.toString();
  }

  /// Pre-build annotation caches that require graph traversal.
  /// 1. PBXBuildFile annotations: scan all build phases, map each file UUID to
  /// "{fileRef name/path} in {phaseName}".
  /// 2. XCConfigurationList annotations: scan PBXProject + target objects for
  /// their `buildConfigurationList` field, map to
  /// "Build configuration list for {ownerType} \"{ownerName}\"".
  void _buildAnnotationCaches() {
    // ISAs that are build phases (have a `files` array of PBXBuildFile UUIDs)
    const buildPhaseIsas = {
      'PBXSourcesBuildPhase',
      'PBXResourcesBuildPhase',
      'PBXFrameworksBuildPhase',
      'PBXCopyFilesBuildPhase',
      'PBXHeadersBuildPhase',
      'PBXShellScriptBuildPhase',
    };

    // ISAs that own a buildConfigurationList
    const targetIsas = {
      'PBXNativeTarget',
      'PBXAggregateTarget',
      'PBXLegacyTarget',
      'PBXProject',
    };

    for (final entry in _objects.entries) {
      final obj = entry.value;
      if (obj is! Map) continue;
      final isa = obj['isa'] as String? ?? '';

      if (buildPhaseIsas.contains(isa)) {
        // Build PBXBuildFile annotations from this build phase
        final phaseName = _phaseNameFor(obj);
        final files = obj['files'];
        if (files is List) {
          for (final fileUuid in files) {
            if (fileUuid is! String) continue;
            final fileObj = _objects[fileUuid];
            if (fileObj is! Map) continue;
            final fileRef = fileObj['fileRef'] as String?;
            if (fileRef == null) continue;
            final refObj = _objects[fileRef];
            String? refLabel;
            if (refObj is Map) {
              final name = refObj['name'];
              if (name is String && name.isNotEmpty) {
                refLabel = name;
              } else {
                final path = refObj['path'];
                if (path is String && path.isNotEmpty) refLabel = path;
              }
            }
            if (refLabel != null && phaseName != null) {
              _buildFileAnnotations[fileUuid] = '$refLabel in $phaseName';
            }
          }
        }
      }

      if (targetIsas.contains(isa)) {
        // Build XCConfigurationList annotations
        final configListUuid = obj['buildConfigurationList'] as String?;
        if (configListUuid == null) continue;

        // CR-05 fix: use the actual ISA instead of hardcoding 'PBXNativeTarget'.
        // This correctly handles PBXAggregateTarget and PBXLegacyTarget as well.
        final String ownerType = isa;

        // Determine owner name.
        // for PBXProject, check the project's own 'name' attribute
        // first; fall back to the first target's name only when absent.
        String? ownerName;
        if (isa == 'PBXProject') {
          // Prefer the project object's own 'name' field.
          final projectName = obj['name'];
          if (projectName is String && projectName.isNotEmpty) {
            ownerName = projectName;
          } else {
            // Fallback: use the first target's name (works for simple projects
            // where project name == target name).
            final targets = obj['targets'];
            if (targets is List && targets.isNotEmpty) {
              final targetUuid = targets.first;
              if (targetUuid is String) {
                final targetObj = _objects[targetUuid];
                if (targetObj is Map) {
                  ownerName = targetObj['name'] as String?;
                }
              }
            }
          }
        } else {
          ownerName = obj['name'] as String?;
        }

        if (ownerName != null) {
          _configListAnnotations[configListUuid] =
              'Build configuration list for $ownerType "$ownerName"';
        }
      }
    }
  }

  /// Returns the canonical name for a build phase object.
  /// Build phases have a `name` attribute (optional). If absent, uses the
  /// default name for the ISA:
  /// - PBXSourcesBuildPhase → "Sources"
  /// - PBXResourcesBuildPhase → "Resources"
  /// - PBXFrameworksBuildPhase → "Frameworks"
  /// - PBXCopyFilesBuildPhase → "CopyFiles"
  /// - PBXHeadersBuildPhase → "Headers"
  /// - PBXShellScriptBuildPhase → uses name attr (always present)
  String? _phaseNameFor(Map<dynamic, dynamic> obj) {
    final name = obj['name'];
    if (name is String && name.isNotEmpty) return name;
    final isa = obj['isa'] as String? ?? '';
    return switch (isa) {
      'PBXSourcesBuildPhase' => 'Sources',
      'PBXResourcesBuildPhase' => 'Resources',
      'PBXFrameworksBuildPhase' => 'Frameworks',
      'PBXCopyFilesBuildPhase' => 'CopyFiles',
      'PBXHeadersBuildPhase' => 'Headers',
      _ => null,
    };
  }

  // ---------------------------------------------------------------------------
  // Root dictionary — special-cases top-level key order and the 'objects' key.
  // Port of PBXProjWriter#write_dictionary_key_value_pair
  // which sets @objects_section = true when key == 'objects' at indent == 1.
  // ---------------------------------------------------------------------------

  /// Writes the root dictionary with the exact key order Nanaimo/Xcode uses:
  /// archiveVersion, classes, objectVersion, objects, rootObject.
  /// Port of Ruby's ordered Hash iteration over sorted keys, plus the
  /// PBXProjWriter logic that detects the 'objects' key at depth 1.
  void _writeRootDictionary(Map<String, dynamic> plist) {
    _out.write('{\n');
    _indent++;

    // Emit keys in the order Nanaimo produces them (alphabetical, but 'objects'
    // triggers the ISA-section handler instead of plain dict write).
    final sortedKeys = plist.keys.toList()..sort();
    for (final key in sortedKeys) {
      final value = plist[key];
      _writeIndent();
      _writeKey(key);
      _out.write(' = ');
      if (key == 'objects' && value is Map) {
        _writeObjectsSection(value.cast<String, dynamic>());
      } else if (key == 'rootObject' && value is String) {
        // Hard-coded annotation: rootObject = UUID /* Project object */;
        _writeStringValue(value, forceAnnotation: 'Project object');
      } else {
        _writeObject(value);
      }
      _out.write(';\n');
    }

    _indent--;
    _out.write('}');
  }

  // ---------------------------------------------------------------------------
  // Object dispatch — port of Writer#write_object
  // ---------------------------------------------------------------------------

  /// Dispatches to the appropriate write method based on runtime type.
  /// Port of Writer#write_object.
  void _writeObject(dynamic value) {
    if (value is Map<String, dynamic>) {
      _writeDictionary(value);
    } else if (value is Map) {
      _writeDictionary(value.cast<String, dynamic>());
    } else if (value is List<int>) {
      _writeData(value);
    } else if (value is List) {
      _writeArray(value);
    } else if (value is String) {
      _writeStringValue(value);
    }
    // other types are not expected in a pbxproj plist
  }

  // ---------------------------------------------------------------------------
  // String write — quoting, annotation reconstruction
  // ---------------------------------------------------------------------------

  /// Writes a string value, quoting if necessary, appending UUID annotation if applicable.
  /// Port of Writer#write_string + write_quoted_string + write_annotation
  /// If [forceAnnotation] is provided, it overrides the UUID lookup (used for rootObject).
  void _writeStringValue(String s, {String? forceAnnotation}) {
    _writeStringQuotedIfNecessary(s);
    final annotation =
        forceAnnotation ?? (_looksLikeUuid(s) ? _annotationFor(s) : null);
    if (annotation != null && annotation.isNotEmpty) {
      _writeAnnotation(annotation);
    }
  }

  /// Writes a string, quoting if [_needsQuoting] returns true.
  /// Port of Writer#write_string_quoted_if_necessary.
  void _writeStringQuotedIfNecessary(String s) {
    if (_needsQuoting(s)) {
      _writeQuotedString(s);
    } else {
      _out.write(s);
    }
  }

  /// Writes a quoted string with [Unicode.quotify] escaping.
  /// Port of Writer#write_quoted_string.
  void _writeQuotedString(String s) {
    _out.write('"');
    _out.write(Unicode.quotify(s));
    _out.write('"');
  }

  /// Writes ` /* annotation */` after a token.
  /// Port of Writer#write_annotation.
  /// Note: Xcode annotations have spaces inside: ` /* text */`
  void _writeAnnotation(String annotation) {
    _out.write(' /* $annotation */');
  }

  // ---------------------------------------------------------------------------
  // Array write — port of Writer#write_array
  // ---------------------------------------------------------------------------

  /// Writes a plist array.
  /// Port of Writer#write_array:
  /// ```ruby
  /// def write_array(object)
  /// write_array_start
  /// value.each { |v| write_array_element(v) }
  /// write_array_end
  /// end
  /// ```
  void _writeArray(List<dynamic> items) {
    _out.write('(');
    if (_newlines) _out.write('\n');
    _indent++;
    for (final item in items) {
      _writeIndent();
      _writeArrayElement(item);
      _out.write(',');
      if (_newlines) {
        _out.write('\n');
      } else {
        _out.write(' ');
      }
    }
    _indent--;
    _writeIndent();
    _out.write(')');
  }

  /// Writes a single array element, appending UUID annotation if applicable.
  void _writeArrayElement(dynamic item) {
    if (item is String) {
      _writeStringValue(item);
    } else {
      _writeObject(item);
    }
  }

  // ---------------------------------------------------------------------------
  // Dictionary write — port of Writer#write_dictionary
  // ---------------------------------------------------------------------------

  /// Writes a regular (non-objects-section) dictionary.
  /// Port of Writer#write_dictionary.
  /// Entries are sorted via [_sortDictEntries] (`isa` first, then alphabetical).
  void _writeDictionary(Map<String, dynamic> dict) {
    _out.write('{');
    if (_newlines) _out.write('\n');
    _indent++;
    final entries = _sortDictEntries(dict);
    for (final entry in entries) {
      _writeIndent();
      _writeKey(entry.key);
      _out.write(' = ');
      _writeObject(entry.value);
      _out.write(';');
      if (_newlines) {
        _out.write('\n');
      } else {
        _out.write(' ');
      }
    }
    _indent--;
    _writeIndent();
    _out.write('}');
  }

  /// Writes a single dictionary key (keys are never annotated).
  void _writeKey(String key) {
    _writeStringQuotedIfNecessary(key);
  }

  // ---------------------------------------------------------------------------
  // Data write — port of Writer#write_data
  // ---------------------------------------------------------------------------

  /// Writes a binary data blob as hex between `<` and `>`.
  /// Port of Writer#write_data:
  /// ```ruby
  /// def write_data(object)
  /// output << '<'
  /// value_for(object).unpack('H*').first.chars.each_with_index do |c, i|
  /// output << "\n" if i > 0 && (i % 16).zero?
  /// output << ' ' if i > 0 && (i % 4).zero?
  /// output << c
  /// end
  /// output << '>'
  /// end
  /// ```
  /// Each byte is written as 2 lowercase hex digits.
  /// Every 4 hex chars (2 bytes), a space is inserted.
  /// Every 16 hex chars (8 bytes), a newline is inserted instead.
  void _writeData(List<int> bytes) {
    _out.write('<');
    // Expand bytes to individual hex characters (like Ruby's unpack('H*').chars)
    var charIdx = 0;
    for (final byte in bytes) {
      final hi = (byte >> 4) & 0xf;
      final lo = byte & 0xf;
      // Each byte contributes 2 hex chars: hi then lo
      for (final nibble in [hi, lo]) {
        if (charIdx > 0 && charIdx % 16 == 0) {
          _out.write('\n');
        } else if (charIdx > 0 && charIdx % 4 == 0) {
          _out.write(' ');
        }
        _out.write(nibble.toRadixString(16));
        charIdx++;
      }
    }
    _out.write('>');
  }

  // ---------------------------------------------------------------------------
  // Objects section — ISA grouping, section comments, flat/pretty dispatch
  // Port of PBXProjWriter#write_dictionary
  // ---------------------------------------------------------------------------

  /// Writes the special `objects` section with ISA grouping and section comments.
  /// Port of PBXProjWriter#write_dictionary when @objects_section is true
  ///:
  /// ```ruby
  /// write_dictionary_start # emit '{\n'
  /// objects_by_isa = value.group_by { |_k, v| isa_for(v) }
  /// objects_by_isa.each do |isa, kvs|
  /// write_newline
  /// output << "/* Begin #{isa} section */"
  /// write_newline
  /// sort_dictionary(kvs, key_can_be_isa: false).each { |k, v| write_dictionary_key_value_pair(k, v) }
  /// output << "/* End #{isa} section */"
  /// write_newline
  /// end
  /// write_dictionary_end # emit '\t}'
  /// ```
  void _writeObjectsSection(Map<String, dynamic> objects) {
    _out.write('{\n');
    _indent++; // now at indent 2 (inside objects dict)

    // Group by ISA
    final grouped = <String, List<MapEntry<String, dynamic>>>{};
    for (final entry in objects.entries) {
      final obj = entry.value;
      String isa = '';
      if (obj is Map) {
        final isaVal = obj['isa'];
        if (isaVal is String) isa = isaVal;
      }
      grouped.putIfAbsent(isa, () => []).add(entry);
    }

    // Sort ISA groups alphabetically
    final isas = grouped.keys.toList()..sort();

    for (final isa in isas) {
      _out.write('\n');
      _out.write('/* Begin $isa section */\n');

      // Sort entries by UUID key (lexicographic)
      final entries = grouped[isa]!..sort((a, b) => a.key.compareTo(b.key));
      final flat = _isFlatIsa(isa);

      for (final entry in entries) {
        // guard the cast — skip malformed entries gracefully (matches
        // Ruby behavior of skipping non-hash entries in the objects section).
        if (entry.value is! Map) continue;
        _writeObjectEntry(
          entry.key,
          (entry.value as Map).cast<String, dynamic>(),
          flat: flat,
        );
      }

      _out.write('/* End $isa section */\n');
    }

    _indent--; // back to indent 1
    _writeIndent();
    _out.write('}');
  }

  /// Writes a single object entry in the objects section.
  /// Format (pretty):
  /// ```
  /// \t\tUUID /* annotation */ = {
  /// \t\t\tisa = ISA;
  /// \t\t\t...
  /// \t\t};
  /// ```
  /// Format (flat):
  /// ```
  /// \t\tUUID /* annotation */ = {isa = ISA; key = val; };
  /// ```
  void _writeObjectEntry(
    String uuid,
    Map<String, dynamic> obj, {
    required bool flat,
  }) {
    _writeIndent();
    // Write UUID with annotation from the object's own name/path/isa
    _out.write(uuid);
    final headerAnnotation = _annotationFor(uuid);
    if (headerAnnotation != null) {
      _writeAnnotation(headerAnnotation);
    }
    _out.write(' = ');

    // Write the object dict (flat or pretty)
    final savedNewlines = _newlines;
    if (flat) _newlines = false;

    _out.write('{');
    if (_newlines) _out.write('\n');
    _indent++;
    final entries = _sortDictEntries(obj);
    for (final entry in entries) {
      _writeIndent();
      _writeKey(entry.key);
      _out.write(' = ');
      _writeObject(entry.value);
      _out.write(';');
      if (_newlines) {
        _out.write('\n');
      } else {
        _out.write(' ');
      }
    }
    _indent--;
    _writeIndent();
    _out.write('}');

    _newlines = savedNewlines;

    _out.write(';\n');
  }

  // ---------------------------------------------------------------------------
  // Indent utility
  // ---------------------------------------------------------------------------

  /// Writes [_indent] tab characters, but only when [_newlines] is true.
  /// Port of Writer#write_indent.
  void _writeIndent() {
    if (_newlines) _out.write('\t' * _indent);
  }

  // ---------------------------------------------------------------------------
  // ISA detection for flat mode
  // ---------------------------------------------------------------------------

  /// Returns true if [isa] requires flat (single-line) format.
  /// Port of PBXProjWriter#flat_dictionary?.
  static bool _isFlatIsa(String isa) =>
      isa == 'PBXBuildFile' || isa == 'PBXFileReference';

  // ---------------------------------------------------------------------------
  // Annotation reconstruction — byte-identity
  // ---------------------------------------------------------------------------

  /// True iff [s] looks like a 24-char uppercase-hex Xcode UUID.
  /// Port of UUID format spec: `^[0-9A-F]{24}$`
  static final RegExp _uuidPattern = RegExp(r'^[0-9A-F]{24}$');
  static bool _looksLikeUuid(String s) => _uuidPattern.hasMatch(s);

  /// Returns the annotation string for [uuid], or null if unknown.
  /// Annotation strategy (priority order):
  /// 1. Hard-coded: `rootObject` UUID → 'Project object'
  /// 2. PBXBuildFile: built-in cache → '{fileRef name} in {phaseName}'
  /// 3. XCConfigurationList: built-in cache → 'Build configuration list for ...'
  /// 4. Generic: prefer `name`, then `path`, then `isa`
  /// 5. UUID not in objects map → null (no annotation)
  String? _annotationFor(String uuid) {
    if (uuid == _rootObjectUuid) return 'Project object';

    // Check PBXBuildFile-specific cache
    final buildFileAnno = _buildFileAnnotations[uuid];
    if (buildFileAnno != null) return buildFileAnno;

    // Check XCConfigurationList-specific cache
    final configListAnno = _configListAnnotations[uuid];
    if (configListAnno != null) return configListAnno;

    final obj = _objects[uuid];
    if (obj is! Map) return null;

    // Build phase default names (used when `name` attr is absent in the plist)
    // PBXSourcesBuildPhase, PBXResourcesBuildPhase, PBXFrameworksBuildPhase
    // do NOT have a `name` attribute in the plist; their display name is derived
    // from ISA. PBXCopyFilesBuildPhase and PBXShellScriptBuildPhase DO have `name`.
    final phaseDefault = _phaseNameFor(obj);
    if (phaseDefault != null) {
      // For build phases: use `name` attr if present, otherwise ISA-derived default
      final name = obj['name'];
      if (name is String && name.isNotEmpty) return name;
      return phaseDefault;
    }

    final name = obj['name'];
    if (name is String && name.isNotEmpty) return name;
    final path = obj['path'];
    if (path is String && path.isNotEmpty) return path;
    // Do NOT fall back to ISA — objects without name/path have no annotation.
    // (e.g. the root PBXGroup in runner.pbxproj has no name/path/annotation)
    return null;
  }

  // ---------------------------------------------------------------------------
  // Quoting rule — port of QUOTED_STRING_REGEXP
  // ---------------------------------------------------------------------------

  /// Quoting rule: a string needs quoting iff:
  /// 1. It is empty, OR
  /// 2. It contains any character outside `[\w.\$/]`, OR
  /// 3. It starts with `___`
  /// Port of Nanaimo::Writer::QUOTED_STRING_REGEXP = `%r{\A\z|[^\w\.\$/]|\A___}`
  static final RegExp _safeChars = RegExp(r'^[\w.\$/]+$');
  static bool _needsQuoting(String s) {
    if (s.isEmpty) return true;
    if (s.startsWith('___')) return true;
    return !_safeChars.hasMatch(s);
  }

  // ---------------------------------------------------------------------------
  // Key sort — isa sorts first within an object dict
  // Port of PBXProjWriter#sort_dictionary
  // ---------------------------------------------------------------------------

  /// Sorts dictionary entries with `isa` key first, then alphabetically.
  /// Port of PBXProjWriter#sort_dictionary:
  /// ```ruby
  /// hash.sort_by do |k, _v|
  /// k == 'isa' ? '' : k
  /// end
  /// ```
  List<MapEntry<String, dynamic>> _sortDictEntries(Map<String, dynamic> dict) {
    final entries = dict.entries.toList();
    entries.sort((a, b) {
      final ka = a.key == 'isa' ? '' : a.key;
      final kb = b.key == 'isa' ? '' : b.key;
      return ka.compareTo(kb);
    });
    return entries;
  }
}
