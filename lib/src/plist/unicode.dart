// Provides quotify/unquotify for ASCII plist string escaping.

import 'next_step_mapping.dart';

/// Utilities for ASCII plist string escaping and unescaping.
/// Port of Nanaimo::Unicode from the Nanaimo 0.4.0 Ruby gem.
class Unicode {
  Unicode._(); // static-only utility class

  // Maps characters that must be escaped when writing quoted strings.
  // Order matches Ruby source verbatim.
  static const Map<String, String> _quoteMap = {
    '\x07': r'\a',
    '\x08': r'\b',
    '\x0c': r'\f',
    '\r': r'\r',
    '\t': r'\t',
    '\x0b': r'\v',
    '\n': r'\n',
    '"': r'\"',
    '\\': r'\\',
    '\x00': r'\U0000',
    '\x01': r'\U0001',
    '\x02': r'\U0002',
    '\x03': r'\U0003',
    '\x04': r'\U0004',
    '\x05': r'\U0005',
    '\x06': r'\U0006',
    '\x0e': r'\U000e',
    '\x0f': r'\U000f',
    '\x10': r'\U0010',
    '\x11': r'\U0011',
    '\x12': r'\U0012',
    '\x13': r'\U0013',
    '\x14': r'\U0014',
    '\x15': r'\U0015',
    '\x16': r'\U0016',
    '\x17': r'\U0017',
    '\x18': r'\U0018',
    '\x19': r'\U0019',
    '\x1a': r'\U001a',
    '\x1b': r'\U001b',
    '\x1c': r'\U001c',
    '\x1d': r'\U001d',
    '\x1e': r'\U001e',
    '\x1f': r'\U001f',
  };

  // Ruby: QUOTE_REGEXP — matches all 34 characters in _quoteMap above.
  // Note 2 from: use raw strings for \xNN in Dart RegExp character classes.
  static final RegExp _quoteRegexp = RegExp(
    r'[\x07\x08\x0c\r\t\x0b\n"\\'
    r'\x00\x01\x02\x03\x04\x05\x06'
    r'\x0e\x0f'
    r'\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f]',
  );

  // Maps the character AFTER a backslash to its decoded value.
  static const Map<String, String> _unquoteMap = {
    '\n': '\n', // backslash-newline (line continuation) → newline
    'a': '\x07', // \a → BEL
    'b': '\x08', // \b → BS
    'f': '\x0c', // \f → FF
    'r': '\r', // \r → CR
    't': '\t', // \t → HT
    'v': '\x0b', // \v → VT
    'n': '\n', // \n → LF
    "'": "'", // \' → '
    '"': '"', // \" → "
    '\\': '\\', // \\ → \
  };

  /// Escapes control characters in [s] for output in a quoted ASCII plist string.
  /// Port of Nanaimo::Unicode.quotify_string.
  /// Characters in [_quoteMap] are replaced with their escape sequences.
  /// Non-ASCII characters (>= 0x80) pass through unchanged as UTF-8 literals.
  static String quotify(String s) {
    return s.replaceAllMapped(_quoteRegexp, (m) => _quoteMap[m.group(0)!]!);
  }

  /// Decodes escape sequences in [s] to their original characters.
  /// Port of Nanaimo::Unicode.unquotify_string.
  /// Handles three forms after a backslash:
  /// 1. `\X` — single-char escape from [_unquoteMap] (e.g., `\n`, `\t`, `\\`)
  /// 2. `\UXXXX` — 4-hex-digit Unicode codepoint (e.g., `\U0041` → `A`)
  /// 3. `\NNN` — 3-octal-digit NeXTSTEP byte, looked up via [nextStepMapping]
  /// Unknown escape sequences preserve the following character literally (Nanaimo behavior).
  static String unquotify(String s) {
    // Fast path: no backslash in the string
    if (!s.contains('\\')) return s;

    final out = StringBuffer();
    var i = 0;
    final length = s.length;

    while (i < length) {
      final ch = s[i];
      if (ch != '\\') {
        out.write(ch);
        i++;
        continue;
      }

      // Backslash found — peek at next character
      if (i + 1 >= length) {
        // Dangling backslash at end — preserve literal (matches Ruby behavior)
        out.write('\\');
        i++;
        continue;
      }

      final next = s[i + 1];

      // Form 2: \UXXXX — 4 hex digits Unicode codepoint
      if (next == 'U' && i + 6 <= length) {
        final hex = s.substring(i + 2, i + 6);
        if (RegExp(r'^[0-9A-Fa-f]{4}$').hasMatch(hex)) {
          out.writeCharCode(int.parse(hex, radix: 16));
          i += 6;
          continue;
        }
      }

      // Form 3: \NNN — 3 octal digits → NeXTSTEP byte → Unicode codepoint
      // Ruby: OCTAL_DIGITS = ('0'..'7') — only digits 0-7 trigger octal handling
      // if the first char is an octal digit but the full 3-digit
      // sequence is not valid octal, preserve \ and next literally rather than
      // silently discarding the backslash.
      if (RegExp(r'[0-7]').hasMatch(next) && i + 4 <= length) {
        final oct = s.substring(i + 1, i + 4);
        if (RegExp(r'^[0-7]{3}$').hasMatch(oct)) {
          final byte = int.parse(oct, radix: 8);
          final cp = nextStepMapping[byte] ?? byte;
          out.writeCharCode(cp);
          i += 4;
          continue;
        }
        // Partial octal — preserve backslash and next character literally
        out.write('\\');
        out.write(next);
        i += 2;
        continue;
      }

      // Form 1: single-char escape from _unquoteMap
      final mapped = _unquoteMap[next];
      if (mapped != null) {
        out.write(mapped);
        i += 2;
        continue;
      }

      // Unknown escape — preserve the character after backslash literally (Nanaimo behavior)
      out.write(next);
      i += 2;
    }
    return out.toString();
  }
}
