import 'package:test/test.dart';
import 'package:dart_xcodeproj/src/project/case_converter.dart';

void main() {
  setUp(() => CaseConverter.clearCaches());

  group('toPlistKey (lowerCamelCase)', () {
    test('source_tree → sourceTree', () {
      expect(CaseConverter.toPlistKey('source_tree'), equals('sourceTree'));
    });

    test(
      'remote_global_id_string → remoteGlobalIDString (hardcoded exception)',
      () {
        expect(
          CaseConverter.toPlistKey('remote_global_id_string'),
          equals('remoteGlobalIDString'),
        );
      },
    );

    test(
      'NEGATIVE: remote_global_id_string must NOT return remoteGlobalIdString',
      () {
        expect(
          CaseConverter.toPlistKey('remote_global_id_string'),
          isNot(equals('remoteGlobalIdString')),
        );
      },
    );

    test('product_type → productType', () {
      expect(CaseConverter.toPlistKey('product_type'), equals('productType'));
    });

    test('build_settings → buildSettings', () {
      expect(
        CaseConverter.toPlistKey('build_settings'),
        equals('buildSettings'),
      );
    });

    test('isa → isa (single word, no transform)', () {
      expect(CaseConverter.toPlistKey('isa'), equals('isa'));
    });

    test('empty string → empty string', () {
      expect(CaseConverter.toPlistKey(''), equals(''));
    });
  });

  group('toPlistKeyUpperFirst (UpperCamelCase)', () {
    test('project_ref → ProjectRef', () {
      expect(
        CaseConverter.toPlistKeyUpperFirst('project_ref'),
        equals('ProjectRef'),
      );
    });

    test('pbx_native_target → PbxNativeTarget', () {
      expect(
        CaseConverter.toPlistKeyUpperFirst('pbx_native_target'),
        equals('PbxNativeTarget'),
      );
    });

    test('isa → Isa', () {
      expect(CaseConverter.toPlistKeyUpperFirst('isa'), equals('Isa'));
    });
  });

  group('toSnakeCase', () {
    test('ProjectRef → project_ref', () {
      expect(CaseConverter.toSnakeCase('ProjectRef'), equals('project_ref'));
    });

    test('sourceTree → source_tree', () {
      expect(CaseConverter.toSnakeCase('sourceTree'), equals('source_tree'));
    });

    test(
      'remoteGlobalIDString → remote_global_id_string (two-pass underscore, )',
      () {
        expect(
          CaseConverter.toSnakeCase('remoteGlobalIDString'),
          equals('remote_global_id_string'),
        );
      },
    );

    test('IDString → id_string (consecutive caps at start)', () {
      expect(CaseConverter.toSnakeCase('IDString'), equals('id_string'));
    });

    test('isa → isa (no caps, no transform)', () {
      expect(CaseConverter.toSnakeCase('isa'), equals('isa'));
    });

    test('foo-bar → foo_bar (hyphens become underscores)', () {
      expect(CaseConverter.toSnakeCase('foo-bar'), equals('foo_bar'));
    });
  });

  group('caching', () {
    test('toPlistKey returns identical result on repeated calls (cached)', () {
      final first = CaseConverter.toPlistKey('source_tree');
      final second = CaseConverter.toPlistKey('source_tree');
      expect(second, equals(first));
    });

    test('after clearCaches(), toPlistKey still returns correct result', () {
      CaseConverter.toPlistKey('source_tree'); // populate cache
      CaseConverter.clearCaches();
      expect(CaseConverter.toPlistKey('source_tree'), equals('sourceTree'));
    });

    test('clearCaches() clears all three caches independently', () {
      // Populate all three caches
      CaseConverter.toPlistKey('source_tree');
      CaseConverter.toPlistKeyUpperFirst('project_ref');
      CaseConverter.toSnakeCase('sourceTree');
      // Clear
      CaseConverter.clearCaches();
      // Verify all three still return correct values after clear
      expect(CaseConverter.toPlistKey('source_tree'), equals('sourceTree'));
      expect(
        CaseConverter.toPlistKeyUpperFirst('project_ref'),
        equals('ProjectRef'),
      );
      expect(CaseConverter.toSnakeCase('sourceTree'), equals('source_tree'));
    });
  });

  group('round-trip identity', () {
    test('toSnakeCase(toPlistKey(source_tree)) → source_tree', () {
      expect(
        CaseConverter.toSnakeCase(CaseConverter.toPlistKey('source_tree')),
        equals('source_tree'),
      );
    });

    test(
      'toSnakeCase(toPlistKey(remote_global_id_string)) → remote_global_id_string (via hardcoded exception)',
      () {
        expect(
          CaseConverter.toSnakeCase(
            CaseConverter.toPlistKey('remote_global_id_string'),
          ),
          equals('remote_global_id_string'),
        );
      },
    );
  });
}
