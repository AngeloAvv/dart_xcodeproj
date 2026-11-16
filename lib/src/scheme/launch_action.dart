// Wraps the LaunchAction node of a .xcscheme XML file.

import 'package:xml/xml.dart';

import 'abstract_scheme_action.dart';
import 'buildable_product_runnable.dart';
import 'command_line_arguments.dart';
import 'environment_variables.dart';
import 'location_scenario_reference.dart';
import 'macro_expansion.dart';
import 'remote_runnable.dart';

/// Wraps a `<LaunchAction>` XML element in a `.xcscheme` file.
class LaunchAction extends AbstractSchemeAction {
  static const String _tag = 'LaunchAction';

  /// Wraps [el], or creates a default `<LaunchAction>` when [el] is omitted (`Debug`).
  ///
  /// Throws an [ArgumentError] if [el] is not a `<LaunchAction>` element.
  LaunchAction([XmlElement? el]) {
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
      xmlElement.setAttribute('launchStyle', '0');
      xmlElement.setAttribute('useCustomWorkingDirectory', boolToString(false));
      xmlElement.setAttribute(
        'ignoresPersistentStateOnLaunch',
        boolToString(false),
      );
      xmlElement.setAttribute('debugDocumentVersioning', boolToString(true));
      xmlElement.setAttribute('debugServiceExtension', 'internal');
      allowLocationSimulation = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Attributes
  // ---------------------------------------------------------------------------

  /// Whether GPS location simulation is allowed when launching.
  ///
  /// A missing attribute reads as `false`.
  bool get allowLocationSimulation =>
      stringToBool(xmlElement.getAttribute('allowLocationSimulation') ?? 'NO');
  set allowLocationSimulation(bool v) =>
      xmlElement.setAttribute('allowLocationSimulation', boolToString(v));

  /// Whether the launch uses a custom working directory.
  ///
  /// A missing attribute reads as `false`.
  bool get useCustomWorkingDirectory => stringToBool(
    xmlElement.getAttribute('useCustomWorkingDirectory') ?? 'NO',
  );
  set useCustomWorkingDirectory(bool v) =>
      xmlElement.setAttribute('useCustomWorkingDirectory', boolToString(v));

  /// Whether document versioning is enabled while debugging.
  ///
  /// A missing attribute reads as `false`.
  bool get debugDocumentVersioning =>
      stringToBool(xmlElement.getAttribute('debugDocumentVersioning') ?? 'NO');
  set debugDocumentVersioning(bool v) =>
      xmlElement.setAttribute('debugDocumentVersioning', boolToString(v));

  /// The `launchStyle` attribute (`0` automatic, `1` wait for executable).
  ///
  /// Setting `null` removes the attribute.
  String? get launchStyle => xmlElement.getAttribute('launchStyle');
  set launchStyle(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('launchStyle');
    } else {
      xmlElement.setAttribute('launchStyle', v);
    }
  }

  // ---------------------------------------------------------------------------
  // BuildableProductRunnable
  // ---------------------------------------------------------------------------

  /// Returns the [BuildableProductRunnable] if present, otherwise null.
  BuildableProductRunnable? get buildableProductRunnable {
    final el = xmlElement.findElements('BuildableProductRunnable').firstOrNull;
    return el != null ? BuildableProductRunnable(el) : null;
  }

  set buildableProductRunnable(BuildableProductRunnable? v) {
    xmlElement.findElements('BuildableProductRunnable').firstOrNull?.remove();
    if (v != null) {
      xmlElement.children.add(v.xmlElement.copy());
    }
  }

  // ---------------------------------------------------------------------------
  // RemoteRunnable
  // ---------------------------------------------------------------------------

  /// Returns the [RemoteRunnable] if present, otherwise null.
  RemoteRunnable? get remoteRunnable {
    final el = xmlElement.findElements('RemoteRunnable').firstOrNull;
    return el != null ? RemoteRunnable(el) : null;
  }

  // ---------------------------------------------------------------------------
  // EnvironmentVariables
  // ---------------------------------------------------------------------------

  /// The [EnvironmentVariables] defined at launch, or `null` if there are none.
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

  /// The [CommandLineArguments] passed at launch, or `null` if there are none.
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
  // LocationScenarioReference
  // ---------------------------------------------------------------------------

  /// The [LocationScenarioReference] that simulates a location, or `null`.
  LocationScenarioReference? get locationScenarioReference {
    final el = xmlElement.findElements('LocationScenarioReference').firstOrNull;
    return el != null ? LocationScenarioReference(el) : null;
  }

  set locationScenarioReference(LocationScenarioReference? v) {
    xmlElement.findElements('LocationScenarioReference').firstOrNull?.remove();
    if (v != null) {
      xmlElement.children.add(v.xmlElement.copy());
    }
  }

  // ---------------------------------------------------------------------------
  // MacroExpansion
  // ---------------------------------------------------------------------------

  /// The [MacroExpansion]s of this launch action.
  List<MacroExpansion> get macroExpansions => xmlElement
      .findElements('MacroExpansion')
      .map(MacroExpansion.new)
      .toList();

  /// Appends a copy of [me] to this launch action.
  void addMacroExpansion(MacroExpansion me) {
    xmlElement.children.add(me.xmlElement.copy());
  }
}
