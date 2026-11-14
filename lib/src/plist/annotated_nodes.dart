/// A plist string carrying an optional trailing `/* ... */` annotation.
/// Port of `Nanaimo::String` with an `annotation`. The ASCII plist writer
/// prints [annotation] exactly as received; it never derives one from [value].
///
/// [annotation] is the text between the comment delimiters, including any
/// padding spaces — for example `' Runner '` is written as `/* Runner */`.
/// A `null` or empty [annotation] writes no comment.
class AnnotatedString {
  /// The string value (for object references: the referenced object's UUID).
  final String value;

  /// The annotation text, or `null` for none.
  final String? annotation;

  const AnnotatedString(this.value, [this.annotation]);

  @override
  bool operator ==(Object other) =>
      other is AnnotatedString &&
      other.value == value &&
      other.annotation == annotation;

  @override
  int get hashCode => Object.hash(value, annotation);

  @override
  String toString() => value;
}

/// A plist dictionary carrying an optional annotation.
/// Port of `Nanaimo::Dictionary` with an `annotation`.
///
/// As entries of the top-level `objects` dictionary, the [annotation] is
/// written after the entry's key (`UUID /* name */ = { ... };`), which is where
/// Ruby's `Project#to_ascii_plist` moves it. Anywhere else it is written after
/// the closing brace.
class AnnotatedDictionary {
  /// The dictionary entries.
  final Map<String, dynamic> value;

  /// The annotation text, or `null` for none. See [AnnotatedString.annotation].
  final String? annotation;

  const AnnotatedDictionary(this.value, [this.annotation]);
}
