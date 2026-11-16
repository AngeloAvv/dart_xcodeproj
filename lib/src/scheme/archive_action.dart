// Wraps the ArchiveAction node of a .xcscheme XML file.

import 'package:xml/xml.dart';

import 'abstract_scheme_action.dart';

/// Wraps an `<ArchiveAction>` XML element in a `.xcscheme` file.
class ArchiveAction extends AbstractSchemeAction {
  static const String _tag = 'ArchiveAction';

  /// Wraps [el], or creates a default `<ArchiveAction>` when [el] is omitted (`Release`, revealed in the Organizer).
  ///
  /// Throws an [ArgumentError] if [el] is not a `<ArchiveAction>` element.
  ArchiveAction([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {
      buildConfiguration = 'Release';
      revealArchiveInOrganizer = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Attributes
  // ---------------------------------------------------------------------------

  /// Whether the archive is revealed in Xcode's Organizer once built.
  ///
  /// A missing attribute reads as `false`.
  bool get revealArchiveInOrganizer =>
      stringToBool(xmlElement.getAttribute('revealArchiveInOrganizer') ?? 'NO');
  set revealArchiveInOrganizer(bool v) =>
      xmlElement.setAttribute('revealArchiveInOrganizer', boolToString(v));

  /// The custom name of the archive, or `null` to use the product's name.
  ///
  /// Setting `null` removes the attribute.
  String? get customArchiveName => xmlElement.getAttribute('customArchiveName');
  set customArchiveName(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('customArchiveName');
    } else {
      xmlElement.setAttribute('customArchiveName', v);
    }
  }
}
