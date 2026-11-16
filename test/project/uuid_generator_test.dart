import 'package:test/test.dart';
import 'package:dart_xcodeproj/src/project/uuid_generator.dart';

void main() {
  group('UuidGenerator.generate', () {
    test('returns 24-char string', () {
      final uuid = UuidGenerator.generate();
      expect(uuid.length, equals(24));
    });

    test('matches ^[0-9A-F]{24}\$ regex', () {
      final uuid = UuidGenerator.generate();
      expect(uuid, matches(RegExp(r'^[0-9A-F]{24}$')));
    });

    test('1000 consecutive calls produce 1000 distinct values', () {
      final seen = <String>{};
      for (var i = 0; i < 1000; i++) {
        seen.add(UuidGenerator.generate());
      }
      expect(seen.length, equals(1000));
    });
  });

  group('UuidGenerator.generateDeterministic', () {
    test('empty string → D41D8CD98F00B204E9800998ECF8427E', () {
      expect(
        UuidGenerator.generateDeterministic(''),
        equals('D41D8CD98F00B204E9800998ECF8427E'),
      );
    });

    test('"hello" → 5D41402ABC4B2A76B9719D911017C592', () {
      expect(
        UuidGenerator.generateDeterministic('hello'),
        equals('5D41402ABC4B2A76B9719D911017C592'),
      );
    });

    test('"test" → 098F6BCD4621D373CADE4E832627B4F6', () {
      expect(
        UuidGenerator.generateDeterministic('test'),
        equals('098F6BCD4621D373CADE4E832627B4F6'),
      );
    });

    test('different paths produce different UUIDs', () {
      final uuidA = UuidGenerator.generateDeterministic('a');
      final uuidB = UuidGenerator.generateDeterministic('b');
      expect(uuidA, isNot(equals(uuidB)));
    });

    test('same path produces same UUID (idempotent)', () {
      final uuid1 = UuidGenerator.generateDeterministic('same');
      final uuid2 = UuidGenerator.generateDeterministic('same');
      expect(uuid1, equals(uuid2));
    });
  });

  group('UuidGenerator.deterministic', () {
    // Expected values computed independently with Python's
    // hashlib.md5(seed.encode('utf-8')).hexdigest().upper().
    test('defaults to the first 24 uppercase hex chars of the MD5', () {
      expect(
        UuidGenerator.deterministic('tool/Runner/Pods'),
        equals('89E916EBEC582DDC4CFB8632'),
      );
    });

    test('length 32 returns the full MD5, as Ruby uuid_for_path', () {
      expect(
        UuidGenerator.deterministic('tool/Runner/Pods', length: 32),
        equals('89E916EBEC582DDC4CFB863221C1D3F5'),
      );
      expect(
        UuidGenerator.deterministic('hello', length: 32),
        equals('5D41402ABC4B2A76B9719D911017C592'),
      );
      expect(
        UuidGenerator.deterministic('hello', length: 32),
        equals(UuidGenerator.generateDeterministic('hello')),
      );
    });

    test('empty seed has a stable value', () {
      expect(
        UuidGenerator.deterministic(''),
        equals('D41D8CD98F00B204E9800998'),
      );
      expect(
        UuidGenerator.deterministic('', length: 32),
        equals('D41D8CD98F00B204E9800998ECF8427E'),
      );
    });

    test('seeds are hashed as UTF-8, so non-ASCII seeds are stable', () {
      expect(
        UuidGenerator.deterministic('café'),
        equals('07117FE4A1EBD544965DC195'),
      );
      expect(
        UuidGenerator.deterministic('日本語'),
        equals('00110AF8B4393EF3F72C50BE'),
      );
      // Outside the BMP: a surrogate pair in UTF-16, four bytes in UTF-8.
      expect(
        UuidGenerator.deterministic('🚀'),
        equals('107040754CAE44F639957714'),
      );
    });

    test('output is uppercase and passes isValid for both lengths', () {
      for (final length in [24, 32]) {
        final uuid = UuidGenerator.deterministic(
          'tool/Runner/Pods',
          length: length,
        );
        expect(uuid, hasLength(length));
        expect(uuid, equals(uuid.toUpperCase()));
        expect(UuidGenerator.isValid(uuid), isTrue);
      }
    });

    test('rejects any length other than 24 or 32 with ArgumentError', () {
      for (final length in [-1, 0, 1, 12, 23, 25, 31, 33, 40]) {
        expect(
          () => UuidGenerator.deterministic('seed', length: length),
          throwsA(
            isA<ArgumentError>()
                .having((e) => e.name, 'name', 'length')
                .having((e) => e.invalidValue, 'invalidValue', length),
          ),
          reason: 'length $length',
        );
      }
    });

    test('the 24-char value is the prefix of the 32-char value', () {
      expect(
        UuidGenerator.deterministic('a/b/c', length: 32),
        startsWith(UuidGenerator.deterministic('a/b/c')),
      );
    });
  });

  group('UuidGenerator.isValid', () {
    test('accepts 24 uppercase hex chars', () {
      expect(UuidGenerator.isValid('ABCDEF0123456789ABCDEF01'), isTrue);
    });

    test('accepts 32 uppercase hex chars', () {
      expect(UuidGenerator.isValid('ABCDEF0123456789ABCDEF0123456789'), isTrue);
    });

    test('accepts the output of generate and generateDeterministic', () {
      expect(UuidGenerator.isValid(UuidGenerator.generate()), isTrue);
      expect(
        UuidGenerator.isValid(UuidGenerator.generateDeterministic('a/b')),
        isTrue,
      );
    });

    test('rejects lengths other than 24 and 32', () {
      expect(UuidGenerator.isValid('ABCDEF0123456789ABCDEF0'), isFalse);
      expect(UuidGenerator.isValid('ABCDEF0123456789ABCDEF012'), isFalse);
      expect(UuidGenerator.isValid('ABCDEF0123456789ABCDEF012345678'), isFalse);
      expect(
        UuidGenerator.isValid('ABCDEF0123456789ABCDEF01234567890'),
        isFalse,
      );
    });

    test('rejects lowercase', () {
      expect(UuidGenerator.isValid('abcdef0123456789abcdef01'), isFalse);
    });

    test('rejects too short', () {
      expect(UuidGenerator.isValid('ABCD'), isFalse);
    });

    test('rejects RFC4122 UUID with hyphens', () {
      expect(
        UuidGenerator.isValid('550e8400-e29b-41d4-a716-446655440000'),
        isFalse,
      );
    });

    test('rejects 32 chars that are not all uppercase hex', () {
      expect(
        UuidGenerator.isValid('abcdef0123456789abcdef0123456789'),
        isFalse,
      );
      expect(
        UuidGenerator.isValid('GGGGEF0123456789ABCDEF0123456789'),
        isFalse,
      );
    });

    test('rejects non-hex characters', () {
      expect(UuidGenerator.isValid('GGGGEF0123456789ABCDEF01'), isFalse);
    });
  });

  group('UuidGenerator.treeHashToPath', () {
    test('scalar at non-zero depth returns toString', () {
      expect(UuidGenerator.treeHashToPath('foo', 4), equals('foo'));
    });

    test('depth=0 returns "|"', () {
      expect(UuidGenerator.treeHashToPath('foo', 0), equals('|'));
    });

    test('Map keys sorted before iteration; format key:value,', () {
      expect(
        UuidGenerator.treeHashToPath({'b': '2', 'a': '1'}, 4),
        equals('a:1,b:2,'),
      );
    });

    test('List comma-joined with no trailing comma', () {
      expect(UuidGenerator.treeHashToPath(['x', 'y', 'z'], 4), equals('x,y,z'));
    });

    test('nested Map recurses with depth-1: inner key:value, present', () {
      final result = UuidGenerator.treeHashToPath({
        'k': {'inner': 'v'},
      }, 4);
      expect(result, contains('inner:v,'));
    });

    test(
      'Map with depth=1 recurses to depth=0 returning "|": result is k:|,',
      () {
        expect(UuidGenerator.treeHashToPath({'k': 'v'}, 1), equals('k:|,'));
      },
    );
  });
}
