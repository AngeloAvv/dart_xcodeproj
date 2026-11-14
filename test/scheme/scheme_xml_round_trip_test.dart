// Regression tests for attribute escaping and comment/text preservation in
// SchemeXmlFormatter (issue #7).

import 'dart:io';

import 'package:dart_xcodeproj/src/scheme/scheme_xml_formatter.dart';
import 'package:dart_xcodeproj/src/scheme/xc_scheme.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('scheme_round_trip_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Opens [fixture], saves it unchanged, and returns the written content.
  Future<String> roundTrip(String fixture) async {
    final scheme = await XCScheme.open(fixture);
    final out = '${tmp.path}/out.xcscheme';
    await scheme.saveAs(out);
    final written = await File(out).readAsString();
    // The output must be well-formed XML.
    expect(() => XmlDocument.parse(written), returnsNormally);
    return written;
  }

  group('byte-identical round trip', () {
    for (final fixture in [
      'test/fixtures/scheme/flutter/ios_Runner.xcscheme',
      'test/fixtures/scheme/flutter/macos_Runner.xcscheme',
      'test/fixtures/scheme/special_chars.xcscheme',
      'test/fixtures/scheme/Complex.xcscheme',
      'test/fixtures/scheme/Demo.xcscheme',
    ]) {
      test(fixture, () async {
        expect(
          await roundTrip(fixture),
          equals(await File(fixture).readAsString()),
        );
      });
    }

    test('Flutter iOS scheme keeps escaped PreAction scriptText', () async {
      final out = await roundTrip(
        'test/fixtures/scheme/flutter/ios_Runner.xcscheme',
      );
      expect(out, contains('&quot;\$FLUTTER_ROOT'));
      expect(out, contains('prepare&#10;"'));
    });
  });

  group('attribute escaping', () {
    test('escapes & < > " and \\n \\r \\t', () {
      final el = XmlElement(XmlName('Foo'), [
        XmlAttribute(XmlName('a'), 'x&y<z>w"q"\n\r\t'),
      ]);
      final out = SchemeXmlFormatter.format(XmlDocument([el]));
      expect(
        out,
        contains('a = "x&amp;y&lt;z&gt;w&quot;q&quot;&#10;&#13;&#9;"'),
      );
      final parsed = XmlDocument.parse(out);
      expect(parsed.rootElement.getAttribute('a'), equals('x&y<z>w"q"\n\r\t'));
    });
  });

  group('comments and text nodes', () {
    test('keeps comments and non-blank text, drops blank text', () {
      final doc = XmlDocument.parse(
        '<Root>\n  <!-- note -->\n  <Child>  hello   &amp; <b/> </Child>\n'
        '  <Blank>   \n </Blank>\n</Root>',
      );
      final out = SchemeXmlFormatter.format(doc);
      expect(
        out,
        equals(
          '<?xml version="1.0" encoding="UTF-8"?>\n'
          '<Root>\n'
          '   <!-- note -->\n'
          '   <Child>\n'
          '       hello &amp; \n'
          '      <b>\n'
          '      </b>\n'
          '   </Child>\n'
          '   <Blank>\n'
          '   </Blank>\n'
          '</Root>\n',
        ),
      );
    });
  });
}
