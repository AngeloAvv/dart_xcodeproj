// — unit tests for XcConfig (..).
// TDD RED phase: these tests are written BEFORE the implementation.

import 'dart:io';

import 'package:dart_xcodeproj/src/config/xc_config.dart';
import 'package:dart_xcodeproj/src/config/xc_config_include_error.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Fixture directory
const _fixturesDir = 'test/fixtures/config';

void _copyFixture(String name, String destDir) {
  File(p.join(_fixturesDir, name)).copySync(p.join(destDir, name));
}

void main() {
  group('XcConfig', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('xc_config_test_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    // -------------------------------------------------------------------------
    // create()
    // -------------------------------------------------------------------------

    group('create()', () {
      test('returns XcConfig with empty attributes', () {
        final config = XcConfig.create('/tmp/test.xcconfig');
        expect(config.attributes, isEmpty);
      });

      test('returns XcConfig with empty includes', () {
        final config = XcConfig.create('/tmp/test.xcconfig');
        expect(config.includes, isEmpty);
      });

      test('returns XcConfig with empty frameworks', () {
        final config = XcConfig.create('/tmp/test.xcconfig');
        expect(config.frameworks, isEmpty);
      });

      test('returns XcConfig with empty weakFrameworks', () {
        final config = XcConfig.create('/tmp/test.xcconfig');
        expect(config.weakFrameworks, isEmpty);
      });

      test('returns XcConfig with empty libraries', () {
        final config = XcConfig.create('/tmp/test.xcconfig');
        expect(config.libraries, isEmpty);
      });

      test('returns XcConfig with empty argFiles', () {
        final config = XcConfig.create('/tmp/test.xcconfig');
        expect(config.argFiles, isEmpty);
      });

      test('returns XcConfig with empty forceLoad', () {
        final config = XcConfig.create('/tmp/test.xcconfig');
        expect(config.forceLoad, isEmpty);
      });

      test('returns XcConfig with empty simpleOtherLdflags', () {
        final config = XcConfig.create('/tmp/test.xcconfig');
        expect(config.simpleOtherLdflags, isEmpty);
      });

      test('stores path', () {
        final config = XcConfig.create('/tmp/test.xcconfig');
        expect(config.path, equals('/tmp/test.xcconfig'));
      });
    });

    // -------------------------------------------------------------------------
    // open()
    // -------------------------------------------------------------------------

    group('open()', () {
      test('parses simple KEY = VALUE pairs', () async {
        _copyFixture('Base.xcconfig', tmp.path);
        final config = await XcConfig.open(p.join(tmp.path, 'Base.xcconfig'));
        expect(config.attributes['PODS_ROOT'], equals(r'$(SRCROOT)/Pods'));
        expect(
          config.attributes['GCC_PREPROCESSOR_DEFINITIONS'],
          equals('DEBUG=1'),
        );
      });

      test('strips // comments (text before // retained)', () async {
        final file = File(p.join(tmp.path, 'commented.xcconfig'));
        file.writeAsStringSync('FOO = bar // this is a comment\nBAZ = qux\n');
        final config = await XcConfig.open(file.path);
        expect(config.attributes['FOO'], equals('bar'));
        expect(config.attributes['BAZ'], equals('qux'));
      });

      test(
        'resolves #include eagerly: attributes from Base appear in Child',
        () async {
          _copyFixture('Base.xcconfig', tmp.path);
          _copyFixture('Child.xcconfig', tmp.path);
          final config = await XcConfig.open(
            p.join(tmp.path, 'Child.xcconfig'),
          );
          // GCC_PREPROCESSOR_DEFINITIONS comes from Base
          expect(
            config.attributes['GCC_PREPROCESSOR_DEFINITIONS'],
            equals('DEBUG=1'),
          );
        },
      );

      test(
        'including config wins on key conflict (child PODS_ROOT overrides Base)',
        () async {
          _copyFixture('Base.xcconfig', tmp.path);
          _copyFixture('Child.xcconfig', tmp.path);
          final config = await XcConfig.open(
            p.join(tmp.path, 'Child.xcconfig'),
          );
          // Child declares PODS_ROOT = $(SRCROOT)/Vendor which overrides Base's $(SRCROOT)/Pods
          expect(config.attributes['PODS_ROOT'], equals(r'$(SRCROOT)/Vendor'));
        },
      );

      test(
        '#include without .xcconfig extension resolves to .xcconfig file',
        () async {
          _copyFixture('Base.xcconfig', tmp.path);
          final noExtFile = File(p.join(tmp.path, 'no_ext.xcconfig'));
          noExtFile.writeAsStringSync('#include "Base"\nMY_KEY = hello\n');
          final config = await XcConfig.open(noExtFile.path);
          expect(config.attributes['PODS_ROOT'], equals(r'$(SRCROOT)/Pods'));
          expect(config.attributes['MY_KEY'], equals('hello'));
        },
      );

      test(
        'missing #include throws XcConfigIncludeError naming the unresolved path',
        () async {
          final file = File(p.join(tmp.path, 'missing.xcconfig'));
          file.writeAsStringSync('#include "DoesNotExist.xcconfig"\nA = 1\n');
          expect(
            () async => await XcConfig.open(file.path),
            throwsA(
              isA<XcConfigIncludeError>().having(
                (e) => e.message,
                'message',
                contains('DoesNotExist'),
              ),
            ),
          );
        },
      );

      test(
        'circular #include throws XcConfigIncludeError naming the cycle',
        () async {
          _copyFixture('Circular_A.xcconfig', tmp.path);
          _copyFixture('Circular_B.xcconfig', tmp.path);
          expect(
            () async =>
                await XcConfig.open(p.join(tmp.path, 'Circular_A.xcconfig')),
            throwsA(
              isA<XcConfigIncludeError>().having(
                (e) => e.message,
                'message',
                allOf(contains('Circular_A'), contains('Circular_B')),
              ),
            ),
          );
        },
      );

      test('parses OTHER_LDFLAGS → frameworks and libraries', () async {
        final file = File(p.join(tmp.path, 'flags.xcconfig'));
        file.writeAsStringSync('OTHER_LDFLAGS = -framework UIKit -lz\n');
        final config = await XcConfig.open(file.path);
        expect(config.frameworks, contains('UIKit'));
        expect(config.libraries, contains('z'));
      });
    });

    // -------------------------------------------------------------------------
    // save()
    // -------------------------------------------------------------------------

    group('save()', () {
      test(
        'byte-identical round-trip on Base.xcconfig with no mutations',
        () async {
          _copyFixture('Base.xcconfig', tmp.path);
          final srcPath = p.join(tmp.path, 'Base.xcconfig');
          final original = File(srcPath).readAsStringSync();
          final config = await XcConfig.open(srcPath);
          final outPath = p.join(tmp.path, 'Base_out.xcconfig');
          final outConfig = XcConfig.create(outPath);
          outConfig.attributes.addAll(config.attributes);
          outConfig.includes.addAll(config.includes);
          await outConfig.save();
          final written = File(outPath).readAsStringSync();
          expect(written, equals(original));
        },
      );

      test(
        'toS() produces #includes first, then KEY=VALUE sorted alphabetically',
        () {
          final config = XcConfig.create('/tmp/t.xcconfig');
          config.attributes['B'] = '2';
          config.attributes['A'] = '1';
          config.attributes['OTHER_LDFLAGS'] = '';
          config.frameworks.add('Foo');
          config.includes.add('Other.xcconfig');
          final s = config.toS();
          expect(s, startsWith('#include "Other.xcconfig"\n'));
          // A comes before B
          final aIdx = s.indexOf('A = 1');
          final bIdx = s.indexOf('B = 2');
          expect(aIdx, lessThan(bIdx));
        },
      );

      test(
        'toS() produces exact string with includes first then sorted keys',
        () {
          final config = XcConfig.create('/tmp/t.xcconfig');
          config.attributes['B'] = '2';
          config.attributes['A'] = '1';
          config.includes.add('Other.xcconfig');
          config.frameworks.add('Foo');
          config.attributes['OTHER_LDFLAGS'] = '-framework Foo';
          final s = config.toS();
          expect(
            s,
            equals(
              '#include "Other.xcconfig"\nA = 1\nB = 2\nOTHER_LDFLAGS = -framework "Foo"\n',
            ),
          );
        },
      );

      test(': forceLoad serializes with space and no quotes', () {
        final config = XcConfig.create('/tmp/t.xcconfig');
        config.forceLoad.add('libfoo.a');
        config.attributes['OTHER_LDFLAGS'] = '';
        final s = config.toS();
        expect(s, contains('-force_load libfoo.a'));
        expect(s, isNot(contains('-force_load "libfoo.a"')));
      });

      test(': frameworks serialize with no space and quoted', () {
        final config = XcConfig.create('/tmp/t.xcconfig');
        config.frameworks.add('UIKit');
        config.attributes['OTHER_LDFLAGS'] = '';
        final s = config.toS();
        expect(s, contains('-framework "UIKit"'));
      });
    });

    // -------------------------------------------------------------------------
    // merge()
    // -------------------------------------------------------------------------

    group('merge()', () {
      test(
        'merge does not overwrite a key that already exists in receiver',
        () {
          final a = XcConfig.create('/tmp/a.xcconfig');
          a.attributes['FOO'] = 'original';
          final b = XcConfig.create('/tmp/b.xcconfig');
          b.attributes['FOO'] = 'overridden';
          final result = a.merge(b);
          expect(result.attributes['FOO'], equals('original'));
        },
      );

      test('merge adds new keys from other', () {
        final a = XcConfig.create('/tmp/a.xcconfig');
        a.attributes['FOO'] = 'original';
        final b = XcConfig.create('/tmp/b.xcconfig');
        b.attributes['BAR'] = 'newvalue';
        final result = a.merge(b);
        expect(result.attributes['BAR'], equals('newvalue'));
      });

      test('shellsplit dedup: same flag in both yields single occurrence', () {
        final a = XcConfig.create('/tmp/a.xcconfig');
        a.frameworks.add('UIKit');
        final b = XcConfig.create('/tmp/b.xcconfig');
        b.frameworks.add('UIKit');
        final result = a.merge(b);
        expect(result.frameworks.where((f) => f == 'UIKit').length, equals(1));
      });

      test('shellsplit concat: different flags in both yields both', () {
        final a = XcConfig.create('/tmp/a.xcconfig');
        a.frameworks.add('UIKit');
        final b = XcConfig.create('/tmp/b.xcconfig');
        b.frameworks.add('Foundation');
        final result = a.merge(b);
        expect(result.frameworks, containsAll(['UIKit', 'Foundation']));
      });

      test('merge is non-mutating: original receiver unchanged', () {
        final a = XcConfig.create('/tmp/a.xcconfig');
        a.attributes['FOO'] = 'original';
        final b = XcConfig.create('/tmp/b.xcconfig');
        b.attributes['FOO'] = 'overridden';
        b.attributes['BAR'] = 'new';
        a.merge(b);
        expect(a.attributes.containsKey('BAR'), isFalse);
        expect(a.attributes['FOO'], equals('original'));
      });
    });
  });
}
