// — unit tests for SchemeXmlFormatter.
// TDD RED phase: these tests are written BEFORE the implementation.

import 'package:dart_xcodeproj/src/scheme/scheme_xml_formatter.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  // ---------------------------------------------------------------------------
  // XML declaration
  // ---------------------------------------------------------------------------

  group('format() — XML declaration', () {
    test('output begins with double-quoted XML declaration', () {
      final doc = XmlDocument([XmlElement(XmlName('Root'))]);
      final out = SchemeXmlFormatter.format(doc);
      expect(out, startsWith('<?xml version="1.0" encoding="UTF-8"?>\n'));
    });

    test('declaration does NOT use single quotes', () {
      final doc = XmlDocument([XmlElement(XmlName('Root'))]);
      final out = SchemeXmlFormatter.format(doc);
      expect(out, isNot(contains("version='1.0'")));
      expect(out, isNot(contains("encoding='UTF-8'")));
    });
  });

  // ---------------------------------------------------------------------------
  // No-attr element
  // ---------------------------------------------------------------------------

  group('format() — element with no attributes', () {
    test('empty element at depth 0 renders <Tag>\\n</Tag>', () {
      final doc = XmlDocument([XmlElement(XmlName('Foo'))]);
      final out = SchemeXmlFormatter.format(doc);
      // After declaration line, should be <Foo>\n</Foo>\n
      final lines = out.split('\n');
      expect(lines[1], equals('<Foo>'));
      expect(lines[2], equals('</Foo>'));
    });
  });

  // ---------------------------------------------------------------------------
  // Single attribute
  // ---------------------------------------------------------------------------

  group('format() — element with 1 attribute', () {
    test('attribute indented 3 spaces, formatted as name = "value"', () {
      final el = XmlElement(XmlName('Foo'), [
        XmlAttribute(XmlName('attr'), 'value'),
      ]);
      final doc = XmlDocument([el]);
      final out = SchemeXmlFormatter.format(doc);
      final lines = out.split('\n');
      // line[1] = '<Foo'
      expect(lines[1], equals('<Foo'));
      // line[2] = '   attr = "value">' (3 spaces before attr at depth 0)
      expect(lines[2], equals('   attr = "value">'));
      // line[3] = '</Foo>'
      expect(lines[3], equals('</Foo>'));
    });
  });

  // ---------------------------------------------------------------------------
  // Two attributes — each on its own line
  // ---------------------------------------------------------------------------

  group('format() — element with 2 attributes', () {
    test('both attributes on separate lines, indented 3 spaces at depth 0', () {
      final el = XmlElement(XmlName('Bar'), [
        XmlAttribute(XmlName('first'), 'one'),
        XmlAttribute(XmlName('second'), 'two'),
      ]);
      final doc = XmlDocument([el]);
      final out = SchemeXmlFormatter.format(doc);
      final lines = out.split('\n');
      expect(lines[1], equals('<Bar'));
      expect(lines[2], equals('   first = "one"'));
      expect(lines[3], equals('   second = "two">'));
      expect(lines[4], equals('</Bar>'));
    });
  });

  // ---------------------------------------------------------------------------
  // Nesting — depth 1 (3-space indent) and depth 2 (6-space indent)
  // ---------------------------------------------------------------------------

  group('format() — nested elements', () {
    test('child at depth 1 is indented 3 spaces', () {
      final child = XmlElement(XmlName('Child'));
      final parent = XmlElement(XmlName('Parent'));
      parent.children.add(child);
      final doc = XmlDocument([parent]);
      final out = SchemeXmlFormatter.format(doc);
      // After declaration + '<Parent>\n', next non-empty line is '   <Child>'
      expect(out, contains('\n   <Child>'));
    });

    test('grandchild at depth 2 is indented 6 spaces', () {
      final grandchild = XmlElement(XmlName('GrandChild'));
      final child = XmlElement(XmlName('Child'));
      child.children.add(grandchild);
      final parent = XmlElement(XmlName('Parent'));
      parent.children.add(child);
      final doc = XmlDocument([parent]);
      final out = SchemeXmlFormatter.format(doc);
      expect(out, contains('\n      <GrandChild>'));
    });

    test('child with attribute: attr line indented 6 spaces (depth 1 + 3)', () {
      final child = XmlElement(XmlName('Child'), [
        XmlAttribute(XmlName('myAttr'), 'val'),
      ]);
      final parent = XmlElement(XmlName('Parent'));
      parent.children.add(child);
      final doc = XmlDocument([parent]);
      final out = SchemeXmlFormatter.format(doc);
      // Child at depth 1 → attr at depth 1+3=4 indent... wait, indent is 3 per level
      // child tag at 3 spaces, attr at 3+3=6 spaces
      expect(out, contains('\n      myAttr = "val">'));
    });
  });

  // ---------------------------------------------------------------------------
  // Trailing newline
  // ---------------------------------------------------------------------------

  group('format() — trailing newline', () {
    test('document ends with a trailing newline', () {
      final doc = XmlDocument([XmlElement(XmlName('Root'))]);
      final out = SchemeXmlFormatter.format(doc);
      expect(out, endsWith('\n'));
    });
  });

  // ---------------------------------------------------------------------------
  // kIndent constant
  // ---------------------------------------------------------------------------

  group('SchemeXmlFormatter constants', () {
    test('kIndent is 3', () {
      expect(SchemeXmlFormatter.kIndent, equals(3));
    });
  });
}
