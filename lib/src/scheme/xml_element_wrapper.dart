// Abstract base class used by all XCScheme wrapper types.
import 'package:xml/xml.dart';

/// Abstract base class for all XCScheme XML element wrappers.
/// Holds [xmlElement] and provides helpers for converting booleans to/from
/// the XML representation used in `.xcscheme` files (`YES`/`NO`).
/// Subclasses call [createXmlElementWithFallback] in their constructors to
/// either wrap an existing [XmlElement] (when opening a scheme file) or create
/// a new element with defaults (when constructing from scratch).
abstract class XmlElementWrapper {
  /// The XML element wrapped by this object.
  late XmlElement xmlElement;

  /// Initialize [xmlElement] from an existing element, or create a new one.
  /// If [nodeOrTarget] is an [XmlElement] whose [XmlName.local] matches
  /// [tagName], assigns it to [xmlElement].
  /// Otherwise creates a fresh `<tagName>` element, assigns it to
  /// [xmlElement], and invokes [fallback] so the caller can set default
  /// attributes and children.
  /// Throws [ArgumentError] if [nodeOrTarget] is an [XmlElement] with the
  /// wrong tag name.
  void createXmlElementWithFallback(
    dynamic nodeOrTarget,
    String tagName,
    void Function() fallback,
  ) {
    if (nodeOrTarget is XmlElement) {
      if (nodeOrTarget.name.local != tagName) {
        throw ArgumentError(
          'Wrong XML tag: expected $tagName, got ${nodeOrTarget.name.local}',
        );
      }
      xmlElement = nodeOrTarget;
    } else {
      xmlElement = XmlElement(XmlName(tagName));
      fallback();
    }
  }

  /// Converts a Dart [bool] to its XML string representation.
  /// Returns `'YES'` for `true`, `'NO'` for `false`.
  String boolToString(bool flag) => flag ? 'YES' : 'NO';

  /// Converts an XML boolean string (`'YES'` / `'NO'`) to a Dart [bool].
  /// Throws [ArgumentError] if [str] is `null` or not `'YES'` / `'NO'`.
  bool stringToBool(String? str) {
    if (str == 'YES') return true;
    if (str == 'NO') return false;
    throw ArgumentError('Expected YES or NO, got: $str');
  }
}
