// Transforms Map<String, dynamic> into Apple ASCII plist text.
// Key design notes:
// - Always emits `// !$*UTF8*$!\n` as the first 14 bytes
// - PBXBuildFile and PBXFileReference use flat (single-line) format
// - All other ISAs use pretty (multi-line, tab-indented) format
// - Objects block is grouped by ISA with section comments
// - Within each ISA group, UUIDs sort lexicographically
// - Within each object dict, `isa` key sorts first
// - Indentation uses TAB characters (\t), NOT spaces
// - Annotations (/* ... */) are printed exactly as received, via
//   [AnnotatedString] / [AnnotatedDictionary] nodes; plain strings are never
//   annotated (port of Nanaimo, where only annotated nodes carry comments)

import 'annotated_nodes.dart';
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
    _out.clear();
    _indent = 0;
    _newlines = true;
    _out.write(_utf8Magic);
    _writeRootDictionary(plist);
    _out.write('\n');
    return _out.toString();
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
    if (value is AnnotatedDictionary) {
      _writeDictionary(value.value);
      _writeAnnotation(value.annotation);
    } else if (value is AnnotatedString) {
      _writeStringQuotedIfNecessary(value.value);
      _writeAnnotation(value.annotation);
    } else if (value is Map<String, dynamic>) {
      _writeDictionary(value);
    } else if (value is Map) {
      _writeDictionary(value.cast<String, dynamic>());
    } else if (value is List<int>) {
      _writeData(value);
    } else if (value is List) {
      _writeArray(value);
    } else if (value is String) {
      _writeStringQuotedIfNecessary(value);
    }
    // other types are not expected in a pbxproj plist
  }

  // ---------------------------------------------------------------------------
  // String write — quoting, annotation reconstruction
  // ---------------------------------------------------------------------------

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

  /// Writes ` /*annotation*/` after a token; nothing for a `null` or empty
  /// [annotation].
  /// Port of Writer#write_annotation. The annotation carries its own padding
  /// spaces (`' Runner '`), as Ruby's `ascii_plist_annotation` does.
  void _writeAnnotation(String? annotation) {
    if (annotation == null || annotation.isEmpty) return;
    _out.write(' /*$annotation*/');
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
      _writeObject(item);
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
  /// Entries may be plain maps or [AnnotatedDictionary]s; the annotation of
  /// the latter is written after the entry's UUID key.
  void _writeObjectsSection(Map<String, dynamic> objects) {
    _out.write('{\n');
    _indent++; // now at indent 2 (inside objects dict)

    // Group by ISA
    final grouped = <String, List<MapEntry<String, dynamic>>>{};
    for (final entry in objects.entries) {
      final obj = _unwrapDictionary(entry.value);
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
        final obj = _unwrapDictionary(entry.value);
        if (obj is! Map) continue;
        _writeObjectEntry(
          entry.key,
          obj.cast<String, dynamic>(),
          annotation: entry.value is AnnotatedDictionary
              ? (entry.value as AnnotatedDictionary).annotation
              : null,
          flat: flat,
        );
      }

      _out.write('/* End $isa section */\n');
    }

    _indent--; // back to indent 1
    _writeIndent();
    _out.write('}');
  }

  /// The plain map behind an [AnnotatedDictionary], or [value] unchanged.
  static dynamic _unwrapDictionary(dynamic value) =>
      value is AnnotatedDictionary ? value.value : value;

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
    required String? annotation,
    required bool flat,
  }) {
    _writeIndent();
    // The UUID key carries the object's own annotation, if it was given one.
    _writeStringQuotedIfNecessary(uuid);
    _writeAnnotation(annotation);
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
