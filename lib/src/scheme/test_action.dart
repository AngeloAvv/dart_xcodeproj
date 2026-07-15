// Wraps the TestAction node of a .xcscheme XML file.

import 'package:xml/xml.dart';

import 'abstract_scheme_action.dart';
import 'buildable_reference.dart';
import 'command_line_arguments.dart';
import 'environment_variables.dart';
import 'macro_expansion.dart';
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
  // MacroExpansion
  // ---------------------------------------------------------------------------

  /// The list of [MacroExpansion] elements associated with this test action.
  List<MacroExpansion> get macroExpansions => xmlElement
      .findElements('MacroExpansion')
      .map(MacroExpansion.new)
      .toList();

  /// Adds a [MacroExpansion], inserted before the `<Testables>` container
  /// when present, matching xcodeproj's `TestAction#add_macro_expansion`.
  void addMacroExpansion(MacroExpansion macroExpansion) {
    final testables = xmlElement.findElements('Testables').firstOrNull;
    if (testables != null) {
      xmlElement.children.insert(
        xmlElement.children.indexOf(testables),
        macroExpansion.xmlElement.copy(),
      );
    } else {
      xmlElement.children.add(macroExpansion.xmlElement.copy());
    }
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

  // ---------------------------------------------------------------------------
  // CodeCoverageTargets
  // ---------------------------------------------------------------------------

  /// The list of [BuildableReference] (code coverage targets) associated
  /// with this test action.
  List<BuildableReference> get codeCoverageTargets {
    final container = xmlElement
        .findElements('CodeCoverageTargets')
        .firstOrNull;
    if (container == null) return <BuildableReference>[];
    return container
        .findElements('BuildableReference')
        .map(BuildableReference.new)
        .toList();
  }

  /// Sets the list of code coverage targets, replacing any existing ones,
  /// and flips `onlyGenerateCoverageForSpecifiedTargets` to true.
  set codeCoverageTargets(List<BuildableReference> targets) {
    xmlElement.setAttribute('onlyGenerateCoverageForSpecifiedTargets', 'YES');
    xmlElement.findElements('CodeCoverageTargets').firstOrNull?.remove();
    final container = XmlElement(XmlName('CodeCoverageTargets'));
    for (final target in targets) {
      container.children.add(target.xmlElement.copy());
    }
    xmlElement.children.add(container);
  }

  /// Adds a [BuildableReference] (code coverage target) to this test action,
  /// and flips `onlyGenerateCoverageForSpecifiedTargets` to true.
  void addCodeCoverageTarget(BuildableReference target) {
    xmlElement.setAttribute('onlyGenerateCoverageForSpecifiedTargets', 'YES');
    var container = xmlElement.findElements('CodeCoverageTargets').firstOrNull;
    if (container == null) {
      container = XmlElement(XmlName('CodeCoverageTargets'));
      xmlElement.children.add(container);
    }
    container.children.add(target.xmlElement.copy());
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

  /// Removes the buildable reference(s) matching [ref]'s content. [ref] need
  /// not be the same element instance added via [addBuildableReference]
  /// (that method stores a copy), so removal matches by XML content.
  void removeBuildableReference(BuildableReference ref) {
    final target = ref.xmlElement.toXmlString();
    xmlElement
        .findElements('BuildableReference')
        .where((e) => e.toXmlString() == target)
        .toList()
        .forEach((e) => e.remove());
  }

  // ---------------------------------------------------------------------------
  // Parallelization / execution ordering
  // ---------------------------------------------------------------------------

  bool get parallelizable =>
      stringToBool(xmlElement.getAttribute('parallelizable') ?? 'NO');
  set parallelizable(bool v) =>
      xmlElement.setAttribute('parallelizable', boolToString(v));

  String? get testExecutionOrdering =>
      xmlElement.getAttribute('testExecutionOrdering');
  set testExecutionOrdering(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('testExecutionOrdering');
    } else {
      xmlElement.setAttribute('testExecutionOrdering', v);
    }
  }

  bool get randomized => testExecutionOrdering == 'random';

  // ---------------------------------------------------------------------------
  // SkippedTests
  // ---------------------------------------------------------------------------

  List<Test> get skippedTests {
    final container = xmlElement.findElements('SkippedTests').firstOrNull;
    if (container == null) return <Test>[];
    return container.findElements('Test').map(Test.new).toList();
  }

  void addSkippedTest(Test test) {
    var container = xmlElement.findElements('SkippedTests').firstOrNull;
    if (container == null) {
      container = XmlElement(XmlName('SkippedTests'));
      xmlElement.children.add(container);
    }
    container.children.add(test.xmlElement.copy());
  }

  // ---------------------------------------------------------------------------
  // SelectedTests / whitelist
  // ---------------------------------------------------------------------------

  bool get useTestSelectionWhitelist => stringToBool(
    xmlElement.getAttribute('useTestSelectionWhitelist') ?? 'NO',
  );
  set useTestSelectionWhitelist(bool v) =>
      xmlElement.setAttribute('useTestSelectionWhitelist', boolToString(v));

  List<Test> get selectedTests {
    final container = xmlElement.findElements('SelectedTests').firstOrNull;
    if (container == null) return <Test>[];
    return container.findElements('Test').map(Test.new).toList();
  }

  void addSelectedTest(Test test) {
    var container = xmlElement.findElements('SelectedTests').firstOrNull;
    if (container == null) {
      container = XmlElement(XmlName('SelectedTests'));
      xmlElement.children.add(container);
    }
    container.children.add(test.xmlElement.copy());
  }
}

/// Wraps a `<Test>` XML element, identifying a single test case referenced
/// from `<SkippedTests>` or `<SelectedTests>`.
class Test extends XmlElementWrapper {
  static const String _tag = 'Test';

  Test([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {});
  }

  /// The fully-qualified identifier of the test class/method.
  String? get identifier => xmlElement.getAttribute('Identifier');
  set identifier(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('Identifier');
    } else {
      xmlElement.setAttribute('Identifier', v);
    }
  }
}
