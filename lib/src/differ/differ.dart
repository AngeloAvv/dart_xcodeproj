import '../project/xcode_project.dart';

/// Port of Ruby Xcodeproj::Differ — UUID-agnostic recursive diff of two
/// project hashes. All methods are static; the class cannot be instantiated.
class Differ {
  Differ._();

  static Map<String, dynamic>? diff(
    dynamic value1,
    dynamic value2, {
    String key1 = 'value_1',
    String key2 = 'value_2',
    String? idKey,
    List<String> keysToIgnore = const [],
  }) {
    dynamic v1 = value1;
    dynamic v2 = value2;
    if (keysToIgnore.isNotEmpty && value1 is Map && value2 is Map) {
      v1 = _cleanHash(Map<String, dynamic>.from(value1), keysToIgnore);
      v2 = _cleanHash(Map<String, dynamic>.from(value2), keysToIgnore);
    }
    if (v1 is Map<String, dynamic> && v2 is Map<String, dynamic>) {
      return _hashDiff(v1, v2, key1: key1, key2: key2, idKey: idKey);
    } else if (v1 is List && v2 is List) {
      return _arrayDiff(v1, v2, key1: key1, key2: key2, idKey: idKey);
    } else {
      return _genericDiff(v1, v2, key1: key1, key2: key2);
    }
  }

  static Map<String, dynamic>? projectDiff(
    dynamic project1,
    dynamic project2, {
    String key1 = 'project_1',
    String key2 = 'project_2',
  }) {
    final h1 = project1 is Map
        ? Map<String, dynamic>.from(project1)
        : (project1 as XcodeProject).toTreeHash();
    final h2 = project2 is Map
        ? Map<String, dynamic>.from(project2)
        : (project2 as XcodeProject).toTreeHash();
    return diff(h1, h2, key1: key1, key2: key2, idKey: 'displayName');
  }

  static Map<String, dynamic>? _hashDiff(
    Map<String, dynamic> v1,
    Map<String, dynamic> v2, {
    required String key1,
    required String key2,
    String? idKey,
  }) {
    if (identical(v1, v2)) return null;
    final result = <String, dynamic>{};
    final allKeys = {...v1.keys, ...v2.keys};
    for (final key in allKeys) {
      final d = diff(v1[key], v2[key], key1: key1, key2: key2, idKey: idKey);
      if (d != null) result[key] = d;
    }
    return result.isEmpty ? null : result;
  }

  static Map<String, dynamic>? _arrayDiff(
    List<dynamic> v1,
    List<dynamic> v2, {
    required String key1,
    required String key2,
    String? idKey,
  }) {
    if (identical(v1, v2)) return null;
    var only1 = _arrayNonUniqueDiff(v1, v2);
    var only2 = _arrayNonUniqueDiff(v2, v1);
    if (v1.isEmpty && v2.isEmpty) return null;

    final matchedDiff = <String, dynamic>{};
    if (idKey != null) {
      final matched1 = <dynamic>[];
      final matched2 = <dynamic>[];
      for (final e1 in List<dynamic>.from(only1)) {
        if (e1 is Map) {
          final idVal = e1[idKey];
          dynamic e2;
          for (final candidate in only2) {
            if (candidate is Map && candidate[idKey] == idVal) {
              e2 = candidate;
              break;
            }
          }
          if (e2 != null) {
            matched1.add(e1);
            matched2.add(e2);
            final d = diff(
              Map<String, dynamic>.from(e1),
              Map<String, dynamic>.from(e2 as Map),
              key1: key1,
              key2: key2,
              idKey: idKey,
            );
            if (d != null) matchedDiff[idVal as String] = d;
          }
        }
      }
      only1 = only1
          .where((e) => !matched1.any((m) => identical(m, e)))
          .toList();
      only2 = only2
          .where((e) => !matched2.any((m) => identical(m, e)))
          .toList();
    }

    if (only1.isEmpty && only2.isEmpty) {
      return matchedDiff.isEmpty ? null : matchedDiff;
    }
    final result = <String, dynamic>{};
    if (only1.isNotEmpty) result[key1] = only1;
    if (only2.isNotEmpty) result[key2] = only2;
    if (matchedDiff.isNotEmpty) result['diff'] = matchedDiff;
    return result;
  }

  // Uses structural (deep) equality so that Map objects with identical content
  // compare equal — Ruby Hash uses value equality by default, Dart Map uses
  // identity. This port preserves Ruby semantics.
  static List<dynamic> _arrayNonUniqueDiff(
    List<dynamic> value1,
    List<dynamic> value2,
  ) {
    final remaining = List<dynamic>.from(value2);
    return value1.where((e1) {
      final idx = remaining.indexWhere((e2) => _deepEqual(e1, e2));
      if (idx != -1) {
        remaining.removeAt(idx);
        return false;
      }
      return true;
    }).toList();
  }

  static bool _deepEqual(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key)) return false;
        if (!_deepEqual(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (!_deepEqual(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  static Map<String, dynamic> _cleanHash(
    Map<String, dynamic> hash,
    List<String> keysToIgnore,
  ) {
    final result = Map<String, dynamic>.from(hash);
    for (final key in keysToIgnore) {
      result.remove(key);
    }
    for (final k in result.keys.toList()) {
      final v = result[k];
      if (v is Map<String, dynamic>) {
        result[k] = _cleanHash(v, keysToIgnore);
      } else if (v is List) {
        result[k] = v
            .map(
              (e) =>
                  e is Map<String, dynamic> ? _cleanHash(e, keysToIgnore) : e,
            )
            .toList();
      }
    }
    return result;
  }

  static Map<String, dynamic>? _genericDiff(
    dynamic v1,
    dynamic v2, {
    required String key1,
    required String key2,
  }) {
    if (v1 == v2) return null;
    return {key1: v1, key2: v2};
  }
}
