// Transforms ASCII plist strings into Dart Map<String, dynamic> objects.
// Key differences from Ruby Nanaimo:
// - Uses String + int _pos index instead of Ruby's StringScanner
// - Annotations from /* ... */ comments are discarded (not stored)
// - Returns plain Dart types: Map, List, String, List<int> for data blobs

import 'plist_format.dart';
import 'plist_parse_error.dart';
import 'unicode.dart';

/// A scanner-based parser for Apple ASCII plist format.
/// Port of Nanaimo::Reader.
/// Parses `.pbxproj`, `.plist` and similar files in Apple ASCII plist format.
/// Usage:
/// ```dart
/// final result = AsciiPlistReader(source).parse();
/// ```
class AsciiPlistReader {
  final String _source;
  int _pos = 0;

  AsciiPlistReader(this._source);

  /// Detects the plist format from the file contents prefix.
  /// Port of Nanaimo::Reader.plist_type.
  /// Returns [PlistFormat.binary] if [contents] starts with `bplist`,
  /// [PlistFormat.xml] if it starts with `<?xml`, and [PlistFormat.ascii]
  /// otherwise.
  static PlistFormat detectFormat(String contents) {
    if (contents.startsWith('bplist')) return PlistFormat.binary;
    if (contents.startsWith('<?xml')) return PlistFormat.xml;
    return PlistFormat.ascii;
  }

  /// Parses the plist source and returns the root dictionary.
  /// Port of Reader#parse!.
  /// The optional `// !$*UTF8*$!` magic comment at the start of `.pbxproj`
  /// files is consumed naturally as a line comment by [_skipWhitespaceAndComments].
  /// Throws [PlistParseError] on malformed input.
  Map<String, dynamic> parse() {
    _pos = 0;
    _skipWhitespaceAndComments();
    if (_pos >= _source.length) {
      throw const PlistParseError('Unexpected end of string while parsing');
    }
    final root = _parseObject();
    _skipWhitespaceAndComments();
    if (_pos < _source.length) {
      final (line, col) = _locationAt(_pos);
      throw PlistParseError('Extra characters after root object', line, col);
    }
    if (root is! Map<String, dynamic>) {
      throw const PlistParseError('Root object must be a dictionary');
    }
    return root;
  }

  // ---------------------------------------------------------------------------
  // Internal parse methods — ported from 1:1
  // ---------------------------------------------------------------------------

  /// Dispatches to the appropriate parse method based on the current character.
  /// Port of Reader#parse_object.
  dynamic _parseObject() {
    _skipWhitespaceAndComments();
    if (_pos >= _source.length) {
      final (line, col) = _locationAt(_pos);
      throw PlistParseError(
        'Unexpected end of string while parsing',
        line,
        col,
      );
    }
    final ch = _source[_pos];
    if (ch == '{') {
      _pos++;
      return _parseDictionary();
    }
    if (ch == '(') {
      _pos++;
      return _parseArray();
    }
    if (ch == '<') {
      _pos++;
      return _parseData();
    }
    if (ch == '"' || ch == "'") {
      final quote = ch;
      _pos++;
      return _parseQuotedString(quote);
    }
    return _parseUnquotedString();
  }

  /// Parses a dictionary `{ key = value; ... }`.
  /// Port of Reader#parse_dictionary.
  /// The opening `{` has already been consumed by [_parseObject].
  /// consolidated `}` check — trailing semicolon before `}` is
  /// optional; consumed if present, then the single `}` check at the top of
  /// the loop closes the dictionary cleanly.
  Map<String, dynamic> _parseDictionary() {
    final result = <String, dynamic>{};
    while (_pos < _source.length) {
      _skipWhitespaceAndComments();
      if (_pos >= _source.length) break; // EOF — outer parse() will report it
      if (_source[_pos] == '}') {
        _pos++;
        break;
      }

      final key = _parseObject();
      if (key is! String) {
        final (line, col) = _locationAt(_pos);
        throw PlistParseError('Dictionary key must be a string', line, col);
      }

      _skipWhitespaceAndComments();
      _expect('=');

      final value = _parseObject();
      result[key] = value;

      _skipWhitespaceAndComments();
      // Consume optional trailing semicolon (last entry in dict may omit it)
      if (_pos < _source.length && _source[_pos] == ';') _pos++;
    }
    return result;
  }

  /// Parses an array `( item, item, )`.
  /// Port of Reader#parse_array.
  /// The opening `(` has already been consumed by [_parseObject].
  List<dynamic> _parseArray() {
    final result = <dynamic>[];
    while (_pos < _source.length) {
      _skipWhitespaceAndComments();
      if (_pos >= _source.length) {
        final (line, col) = _locationAt(_pos);
        throw PlistParseError('Unexpected end of array', line, col);
      }
      if (_source[_pos] == ')') {
        _pos++;
        break;
      }

      result.add(_parseObject());

      _skipWhitespaceAndComments();
      if (_pos >= _source.length) {
        final (line, col) = _locationAt(_pos);
        throw PlistParseError('Unexpected end of array', line, col);
      }
      if (_source[_pos] == ')') {
        _pos++;
        break;
      }
      _expect(',');
    }
    return result;
  }

  /// Parses a data blob `<HEXHEX>` into a [List<int>] of bytes.
  /// Port of Reader#parse_data.
  /// The opening `<` has already been consumed by [_parseObject].
  List<int> _parseData() {
    final hexBuffer = StringBuffer();
    while (_pos < _source.length && _source[_pos] != '>') {
      final ch = _source[_pos];
      // Skip whitespace between hex pairs
      if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
        _pos++;
        continue;
      }
      hexBuffer.write(ch);
      _pos++;
    }
    if (_pos >= _source.length) {
      final (line, col) = _locationAt(_pos);
      throw PlistParseError("Data missing closing '>'", line, col);
    }
    _pos++; // consume '>'

    final hex = hexBuffer.toString();
    if (hex.length.isOdd) {
      final (line, col) = _locationAt(_pos);
      throw PlistParseError(
        'Data has an uneven number of hex digits',
        line,
        col,
      );
    }
    if (hex.isNotEmpty && !RegExp(r'^[0-9A-Fa-f]+$').hasMatch(hex)) {
      final (line, col) = _locationAt(_pos);
      throw PlistParseError('Data contains invalid hex characters', line, col);
    }

    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  /// Parses a quoted string (single or double quotes).
  /// Port of Reader#parse_quotedstring.
  /// The opening quote has already been consumed by [_parseObject].
  /// Uses [Unicode.unquotify] to decode escape sequences.
  /// Throws [PlistParseError] if the closing quote is never found (CR-03 fix).
  String _parseQuotedString(String quote) {
    final raw = StringBuffer();
    while (_pos < _source.length) {
      final ch = _source[_pos];
      if (ch == quote) {
        _pos++;
        return Unicode.unquotify(raw.toString());
      }
      if (ch == '\\' && _pos + 1 < _source.length) {
        // Include the backslash and the next char in raw — unquotify handles them
        raw.write(ch);
        raw.write(_source[_pos + 1]);
        _pos += 2;
        continue;
      }
      raw.write(ch);
      _pos++;
    }
    // Reached end of input without finding the closing quote.
    final (line, col) = _locationAt(_pos);
    throw PlistParseError('Unterminated quoted string', line, col);
  }

  // Unquoted string character class: [\w_$/:.-]+
  // Port of: @scanner.scan(%r{[\w_$/:.-]+}o)
  static final RegExp _unquotedStringPattern = RegExp(r'[\w_$/:.\-]+');

  /// Parses an unquoted string (identifiers, UUIDs, paths, etc.).
  /// Port of Reader#parse_string.
  String _parseUnquotedString() {
    final match = _unquotedStringPattern.matchAsPrefix(_source, _pos);
    if (match == null) {
      final (line, col) = _locationAt(_pos);
      final char = _pos < _source.length ? _source[_pos] : '<eof>';
      throw PlistParseError(
        'Invalid character ${char.codeUnits} in unquoted string',
        line,
        col,
      );
    }
    _pos = match.end;
    return match.group(0)!;
  }

  /// Skips whitespace and both `//` line comments and `/* */` block comments.
  /// Port of Reader#skip_to_non_space_matching_annotations.
  /// Annotations (comment content) are discarded — writer reconstructs them.
  void _skipWhitespaceAndComments() {
    while (_pos < _source.length) {
      _skipWhitespace();
      if (_pos + 1 < _source.length &&
          _source[_pos] == '/' &&
          _source[_pos + 1] == '/') {
        _pos += 2;
        _readLineComment();
      } else if (_pos + 1 < _source.length &&
          _source[_pos] == '/' &&
          _source[_pos + 1] == '*') {
        _pos += 2;
        _readBlockComment();
      } else {
        break;
      }
    }
  }

  /// Skips horizontal and vertical whitespace characters.
  /// Port of Reader#eat_whitespace!.
  /// Handles: space, tab, newline (\n \r), vertical tab, form feed.
  /// U+2028/U+2029 are NOT treated as whitespace (CR-02 fix).
  void _skipWhitespace() {
    while (_pos < _source.length) {
      final ch = _source[_pos];
      if (ch == ' ' ||
          ch == '\t' ||
          ch == '\n' ||
          ch == '\r' ||
          ch == '\x0b' ||
          ch == '\x0c') {
        _pos++;
      } else {
        break;
      }
    }
  }

  /// Reads and discards a `//` line comment to end of line.
  /// Port of Reader#read_singleline_comment.
  /// Only \n and \r terminate a line comment — U+2028/U+2029 are NOT line
  /// terminators in the Apple plist grammar (CR-01 fix).
  void _readLineComment() {
    while (_pos < _source.length) {
      final ch = _source[_pos];
      _pos++;
      if (ch == '\n' || ch == '\r') break;
    }
  }

  /// Reads and discards a `/* ... */` block comment.
  /// Port of Reader#read_multiline_comment.
  void _readBlockComment() {
    while (_pos + 1 < _source.length) {
      if (_source[_pos] == '*' && _source[_pos + 1] == '/') {
        _pos += 2;
        return;
      }
      _pos++;
    }
    // Unterminated block comment — consume to end (lenient, matching Ruby behavior)
    _pos = _source.length;
  }

  /// Expects the next character to be [expected], advances past it, or throws.
  /// Port of StringScanner.skip usage.
  void _expect(String expected) {
    if (_pos >= _source.length || _source[_pos] != expected) {
      final (line, col) = _locationAt(_pos);
      final found = _pos < _source.length ? _source[_pos] : '<eof>';
      throw PlistParseError(
        "Expected '$expected' but found '$found'",
        line,
        col,
      );
    }
    _pos++;
  }

  /// Computes (line, column) of position [pos] in [_source].
  /// Port of Reader#location_in.
  /// Line and column are 1-based.
  /// CR-04 fix: initialise col at 0 so the loop counts characters BEFORE [pos].
  /// After the loop, col equals the number of non-newline chars on the current
  /// line before [pos]; returning col+1 gives the correct 1-based column.
  (int, int) _locationAt(int pos) {
    var line = 1;
    var col = 0;
    final limit = pos < _source.length ? pos : _source.length;
    for (var i = 0; i < limit; i++) {
      if (_source[i] == '\n') {
        line++;
        col = 0;
      } else {
        col++;
      }
    }
    return (line, col + 1);
  }
}
