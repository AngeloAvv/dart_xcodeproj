// Wraps the TestAction node of a .xcscheme XML file.

import 'package:xml/xml.dart';

import 'abstract_scheme_action.dart';
import 'buildable_reference.dart';
import 'command_line_arguments.dart';
import 'environment_variables.dart';
import 'xml_element_wrapper.dart';

/// Wraps a `<TestAction>` XML element in a `.xcscheme` file.
class TestAction extends AbstractSchemeAction {
  static const String _tag = 'TestAction';

  TestAction([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {
      buildConfiguration = 'Debug';
      xmlElement.setAttribute(
        'selectedDebuggerIdentifier',
        'Xcode.DebuggerFoundation.Debugger.LLDB',
      );
      xmlElement.setAttribute(
        'selectedLauncherIdentifier',
        'Xcode.DebuggerFoundation.Launcher.LLDB',
      );
      shouldUseLaunchSchemeArgsEnv = true;
      // Add empty Testables container per Ruby initialize
      xmlElement.children.add(XmlElement(XmlName('Testables')));
    });
  }

  // ---------------------------------------------------------------------------
  // Attributes
  // ---------------------------------------------------------------------------

  bool get shouldUseLaunchSchemeArgsEnv => stringToBool(
    xmlElement.getAttribute('shouldUseLaunchSchemeArgsEnv') ?? 'NO',
  );
  set shouldUseLaunchSchemeArgsEnv(bool v) =>
      xmlElement.setAttribute('shouldUseLaunchSchemeArgsEnv', boolToString(v));

  bool get codeCoverageEnabled =>
      stringToBool(xmlElement.getAttribute('codeCoverageEnabled') ?? 'NO');
  set codeCoverageEnabled(bool v) =>
      xmlElement.setAttribute('codeCoverageEnabled', boolToString(v));

  // ---------------------------------------------------------------------------
  // Testables
  // ---------------------------------------------------------------------------

  /// The list of [TestableReference] associated with this test action.
  List<TestableReference> get testables {
    final container = xmlElement.findElements('Testables').firstOrNull;
    if (container == null) return <TestableReference>[];
    return container
        .findElements('TestableReference')
        .map(TestableReference.new)
        .toList();
  }

  /// Adds a [TestableReference] to the `<Testables>` container.
  void addTestable(TestableReference testable) {
    var container = xmlElement.findElements('Testables').firstOrNull;
    if (container == null) {
      container = XmlElement(XmlName('Testables'));
      xmlElement.children.add(container);
    }
    container.children.add(testable.xmlElement.copy());
  }

  // ---------------------------------------------------------------------------
  // EnvironmentVariables
  // ---------------------------------------------------------------------------

  /// The EnvironmentVariables for this test action.
  /// Returns null if no `<EnvironmentVariables>` child is present.
  EnvironmentVariables? get environmentVariables {
    final el = xmlElement.findElements('EnvironmentVariables').firstOrNull;
    return el != null ? EnvironmentVariables(el) : null;
  }

  set environmentVariables(EnvironmentVariables? v) {
    xmlElement.findElements('EnvironmentVariables').firstOrNull?.remove();
    if (v != null) {
      xmlElement.children.add(v.xmlElement.copy());
    }
  }

  // ---------------------------------------------------------------------------
  // CommandLineArguments
  // ---------------------------------------------------------------------------

  /// The CommandLineArguments for this test action.
  /// Returns null if no `<CommandLineArguments>` child is present.
  CommandLineArguments? get commandLineArguments {
    final el = xmlElement.findElements('CommandLineArguments').firstOrNull;
    return el != null ? CommandLineArguments(el) : null;
  }

  set commandLineArguments(CommandLineArguments? v) {
    xmlElement.findElements('CommandLineArguments').firstOrNull?.remove();
    if (v != null) {
      xmlElement.children.add(v.xmlElement.copy());
    }
  }
}

/// Wraps a `<TestableReference>` XML element.
class TestableReference extends XmlElementWrapper {
  static const String _tag = 'TestableReference';

  TestableReference([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {
      skipped = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Attributes
  // ---------------------------------------------------------------------------

  bool get skipped => stringToBool(xmlElement.getAttribute('skipped') ?? 'NO');
  set skipped(bool v) => xmlElement.setAttribute('skipped', boolToString(v));

  // ---------------------------------------------------------------------------
  // BuildableReferences
  // ---------------------------------------------------------------------------

  List<BuildableReference> get buildableReferences => xmlElement
      .findElements('BuildableReference')
      .map(BuildableReference.new)
      .toList();

  void addBuildableReference(BuildableReference ref) {
    xmlElement.children.add(ref.xmlElement.copy());
  }
}
