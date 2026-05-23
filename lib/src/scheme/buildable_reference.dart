// Wraps the BuildableReference node of a .xcscheme XML file.
// CRITICAL: — attribute serialization order must be:
// BuildableIdentifier, BlueprintIdentifier, BuildableName, BlueprintName, ReferencedContainer

import 'package:xml/xml.dart';

import 'xml_element_wrapper.dart';

/// Wraps a `<BuildableReference>` XML element in a `.xcscheme` file.
/// A BuildableReference is a reference to a buildable product (typically an
/// Xcode target). The attribute serialization order is significant:
/// `BuildableIdentifier`, `BlueprintIdentifier`, `BuildableName`,
/// `BlueprintName`, `ReferencedContainer`.
class BuildableReference extends XmlElementWrapper {
  static const String _tag = 'BuildableReference';

  /// Ordered attribute names for correct serialization.
  static const List<String> _attrOrder = [
    'BuildableIdentifier',
    'BlueprintIdentifier',
    'BuildableName',
    'BlueprintName',
    'ReferencedContainer',
  ];

  BuildableReference([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {
      xmlElement.setAttribute('BuildableIdentifier', 'primary');
    });
  }

  // ---------------------------------------------------------------------------
  // Attribute accessors
  // ---------------------------------------------------------------------------

  String? get buildableIdentifier =>
      xmlElement.getAttribute('BuildableIdentifier');
  set buildableIdentifier(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('BuildableIdentifier');
    } else {
      xmlElement.setAttribute('BuildableIdentifier', v);
    }
  }

  String? get blueprintIdentifier =>
      xmlElement.getAttribute('BlueprintIdentifier');
  set blueprintIdentifier(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('BlueprintIdentifier');
    } else {
      xmlElement.setAttribute('BlueprintIdentifier', v);
    }
  }

  String? get buildableName => xmlElement.getAttribute('BuildableName');
  set buildableName(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('BuildableName');
    } else {
      xmlElement.setAttribute('BuildableName', v);
    }
  }

  String? get blueprintName => xmlElement.getAttribute('BlueprintName');
  set blueprintName(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('BlueprintName');
    } else {
      xmlElement.setAttribute('BlueprintName', v);
    }
  }

  String? get referencedContainer =>
      xmlElement.getAttribute('ReferencedContainer');
  set referencedContainer(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('ReferencedContainer');
    } else {
      xmlElement.setAttribute('ReferencedContainer', v);
    }
  }

  // ---------------------------------------------------------------------------
  // setReferenceTarget — serialization order enforcement
  // ---------------------------------------------------------------------------

  /// Sets all reference attributes at once, enforcing correct attribute order:
  /// BuildableIdentifier, BlueprintIdentifier, BuildableName, BlueprintName,
  /// ReferencedContainer.
  /// Removes all 5 attributes first, then adds in the correct order so that
  /// XML serialization preserves the Xcode-expected order.
  void setReferenceTarget(
    String blueprintId,
    String buildableName_,
    String blueprintName_,
    String referencedContainer_,
  ) {
    // Remove all 5 in order to reset attribute order
    for (final name in _attrOrder) {
      xmlElement.removeAttribute(name);
    }
    // Re-add in the correct order
    xmlElement.setAttribute('BuildableIdentifier', 'primary');
    xmlElement.setAttribute('BlueprintIdentifier', blueprintId);
    xmlElement.setAttribute('BuildableName', buildableName_);
    xmlElement.setAttribute('BlueprintName', blueprintName_);
    xmlElement.setAttribute('ReferencedContainer', referencedContainer_);
  }
}
