// Wraps the LocationScenarioReference node of a .xcscheme XML file.

import 'package:xml/xml.dart';

import 'xml_element_wrapper.dart';

/// Wraps a `<LocationScenarioReference>` XML element in a `.xcscheme` file.
/// A LocationScenarioReference is a reference to a simulated GPS location
/// associated with a scheme's launch action.
class LocationScenarioReference extends XmlElementWrapper {
  static const String _tag = 'LocationScenarioReference';

  LocationScenarioReference([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {
      identifier = '';
      referenceType = '0';
    });
  }

  // ---------------------------------------------------------------------------
  // Attributes
  // ---------------------------------------------------------------------------

  /// The identifier (built-in location scenario or path to a GPX file).
  String? get identifier => xmlElement.getAttribute('identifier');
  set identifier(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('identifier');
    } else {
      xmlElement.setAttribute('identifier', v);
    }
  }

  /// The reference type: '0' for custom GPX file, '1' for built-in location.
  String? get referenceType => xmlElement.getAttribute('referenceType');
  set referenceType(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('referenceType');
    } else {
      xmlElement.setAttribute('referenceType', v);
    }
  }
}
