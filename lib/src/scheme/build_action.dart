// Wraps the BuildAction node of a .xcscheme XML file.
// Note: BuildAction is NOT a subclass of AbstractSchemeAction (no buildConfiguration),
// but it does have preActions/postActions like the abstract base.

import 'package:xml/xml.dart';

import 'abstract_scheme_action.dart';
import 'buildable_reference.dart';
import 'xml_element_wrapper.dart';

/// Wraps a `<BuildAction>` XML element in a `.xcscheme` file.
/// Exposes [parallelizeBuildables], [buildImplicitDependencies], and [entries].
/// Unlike the other actions, BuildAction does NOT have a `buildConfiguration`
/// attribute (it is not a subclass of AbstractSchemeAction in the Ruby source,
/// but it does share pre/post action support).
class BuildAction extends AbstractSchemeAction {
  static const String _tag = 'BuildAction';

  BuildAction([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {
      parallelizeBuildables = true;
      buildImplicitDependencies = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Attributes
  // ---------------------------------------------------------------------------

  bool get parallelizeBuildables =>
      stringToBool(xmlElement.getAttribute('parallelizeBuildables') ?? 'NO');
  set parallelizeBuildables(bool v) =>
      xmlElement.setAttribute('parallelizeBuildables', boolToString(v));

  bool get buildImplicitDependencies => stringToBool(
    xmlElement.getAttribute('buildImplicitDependencies') ?? 'NO',
  );
  set buildImplicitDependencies(bool v) =>
      xmlElement.setAttribute('buildImplicitDependencies', boolToString(v));

  // ---------------------------------------------------------------------------
  // BuildActionEntries
  // ---------------------------------------------------------------------------

  /// The list of [BuildActionEntry] nodes.
  List<BuildActionEntry> get entries {
    final container = xmlElement.findElements('BuildActionEntries').firstOrNull;
    if (container == null) return <BuildActionEntry>[];
    return container
        .findElements('BuildActionEntry')
        .map(BuildActionEntry.new)
        .toList();
  }

  /// Adds a [BuildActionEntry] to the `<BuildActionEntries>` container.
  void addEntry(BuildActionEntry entry) {
    var container = xmlElement.findElements('BuildActionEntries').firstOrNull;
    if (container == null) {
      container = XmlElement(XmlName('BuildActionEntries'));
      xmlElement.children.add(container);
    }
    container.children.add(entry.xmlElement.copy());
  }
}

/// Wraps a `<BuildActionEntry>` XML element.
class BuildActionEntry extends XmlElementWrapper {
  static const String _tag = 'BuildActionEntry';

  BuildActionEntry([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {
      // Default: only buildForAnalyzing is true; the rest are false.
      buildForTesting = false;
      buildForRunning = false;
      buildForProfiling = false;
      buildForArchiving = false;
      buildForAnalyzing = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Build-for booleans
  // ---------------------------------------------------------------------------

  bool get buildForTesting =>
      stringToBool(xmlElement.getAttribute('buildForTesting') ?? 'NO');
  set buildForTesting(bool v) =>
      xmlElement.setAttribute('buildForTesting', boolToString(v));

  bool get buildForRunning =>
      stringToBool(xmlElement.getAttribute('buildForRunning') ?? 'NO');
  set buildForRunning(bool v) =>
      xmlElement.setAttribute('buildForRunning', boolToString(v));

  bool get buildForProfiling =>
      stringToBool(xmlElement.getAttribute('buildForProfiling') ?? 'NO');
  set buildForProfiling(bool v) =>
      xmlElement.setAttribute('buildForProfiling', boolToString(v));

  bool get buildForArchiving =>
      stringToBool(xmlElement.getAttribute('buildForArchiving') ?? 'NO');
  set buildForArchiving(bool v) =>
      xmlElement.setAttribute('buildForArchiving', boolToString(v));

  bool get buildForAnalyzing =>
      stringToBool(xmlElement.getAttribute('buildForAnalyzing') ?? 'NO');
  set buildForAnalyzing(bool v) =>
      xmlElement.setAttribute('buildForAnalyzing', boolToString(v));

  // ---------------------------------------------------------------------------
  // BuildableReferences
  // ---------------------------------------------------------------------------

  /// The list of BuildableReferences in this entry.
  List<BuildableReference> get buildableReferences => xmlElement
      .findElements('BuildableReference')
      .map(BuildableReference.new)
      .toList();

  /// Adds a [BuildableReference] to this entry.
  void addBuildableReference(BuildableReference ref) {
    xmlElement.children.add(ref.xmlElement.copy());
  }

  /// Removes a [BuildableReference] from this entry.
  void removeBuildableReference(BuildableReference ref) {
    ref.xmlElement.remove();
  }
}
