// Provides read/write support for Xcode Scheme documents (.xcscheme files).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'analyze_action.dart';
import 'archive_action.dart';
import 'build_action.dart';
import 'launch_action.dart';
import 'profile_action.dart';
import 'scheme_xml_formatter.dart';
import 'test_action.dart';

/// Container for an Xcode `.xcscheme` document.
/// Supports creating new schemes from scratch ([create]) and opening existing
/// scheme files ([open]). Serializes back to disk via [save] or [saveAs].
/// Action element accessors return lazy [XmlElement] lookups from the parsed
/// document. wraps these as typed objects (BuildAction, TestAction, …).
/// ## Security (T-06-S1)
/// [XmlDocument.parse] from `package:xml` does **not** resolve external
/// entities, so XXE is not applicable. (Verified against xml 6.6.1.)
/// ## Security (T-06-S2)
/// [saveAs] normalizes the path via `p.normalize`. This is a local developer
/// tool; path traversal via `../` is accepted as intended use.
class XCScheme {
  String? _path;

  /// The underlying XML document.
  final XmlDocument document;

  XCScheme._(this._path, this.document);

  /// The normalized absolute path to the `.xcscheme` file, or `null` for a
  /// newly created scheme that has not yet been saved.
  String? get path => _path;

  // ---------------------------------------------------------------------------
  // Factory constructors
  // ---------------------------------------------------------------------------

  /// SCH-01: Creates a new scheme with Xcode's default 6 action elements.
  /// Defaults follow Ruby `XCScheme#initialize(file_path=nil)` lines 46–58
  ///. The returned scheme has `path == null`; call [saveAs] to
  /// persist it.
  static XCScheme create() {
    final root = XmlElement(XmlName('Scheme'), [
      XmlAttribute(XmlName('LastUpgradeVersion'), '1500'),
      XmlAttribute(XmlName('version'), '1.3'),
    ]);

    // BuildAction defaults
    root.children.add(
      XmlElement(XmlName('BuildAction'), [
        XmlAttribute(XmlName('parallelizeBuildables'), 'YES'),
        XmlAttribute(XmlName('buildImplicitDependencies'), 'YES'),
      ]),
    );

    // TestAction defaults
    root.children.add(
      XmlElement(XmlName('TestAction'), [
        XmlAttribute(XmlName('buildConfiguration'), 'Debug'),
        XmlAttribute(
          XmlName('selectedDebuggerIdentifier'),
          'Xcode.DebuggerFoundation.Debugger.LLDB',
        ),
        XmlAttribute(
          XmlName('selectedLauncherIdentifier'),
          'Xcode.DebuggerFoundation.Launcher.LLDB',
        ),
        XmlAttribute(XmlName('shouldUseLaunchSchemeArgsEnv'), 'YES'),
      ]),
    );

    // LaunchAction defaults
    root.children.add(
      XmlElement(XmlName('LaunchAction'), [
        XmlAttribute(XmlName('buildConfiguration'), 'Debug'),
        XmlAttribute(
          XmlName('selectedDebuggerIdentifier'),
          'Xcode.DebuggerFoundation.Debugger.LLDB',
        ),
        XmlAttribute(
          XmlName('selectedLauncherIdentifier'),
          'Xcode.DebuggerFoundation.Launcher.LLDB',
        ),
        XmlAttribute(XmlName('launchStyle'), '0'),
        XmlAttribute(XmlName('useCustomWorkingDirectory'), 'NO'),
        XmlAttribute(XmlName('ignoresPersistentStateOnLaunch'), 'NO'),
        XmlAttribute(XmlName('debugDocumentVersioning'), 'YES'),
        XmlAttribute(XmlName('debugServiceExtension'), 'internal'),
        XmlAttribute(XmlName('allowLocationSimulation'), 'YES'),
      ]),
    );

    // ProfileAction defaults
    root.children.add(
      XmlElement(XmlName('ProfileAction'), [
        XmlAttribute(XmlName('buildConfiguration'), 'Release'),
        XmlAttribute(XmlName('shouldUseLaunchSchemeArgsEnv'), 'YES'),
        XmlAttribute(XmlName('savedToolIdentifier'), ''),
        XmlAttribute(XmlName('useCustomWorkingDirectory'), 'NO'),
        XmlAttribute(XmlName('debugDocumentVersioning'), 'YES'),
      ]),
    );

    // AnalyzeAction defaults
    root.children.add(
      XmlElement(XmlName('AnalyzeAction'), [
        XmlAttribute(XmlName('buildConfiguration'), 'Debug'),
      ]),
    );

    // ArchiveAction defaults
    root.children.add(
      XmlElement(XmlName('ArchiveAction'), [
        XmlAttribute(XmlName('buildConfiguration'), 'Release'),
        XmlAttribute(XmlName('revealArchiveInOrganizer'), 'YES'),
      ]),
    );

    final doc = XmlDocument([root]);
    return XCScheme._(null, doc);
  }

  /// SCH-02: Opens an existing `.xcscheme` file.
  /// Reads the file at [path] and parses it as XML via [XmlDocument.parse].
  /// Throws [FileSystemException] if the file does not exist.
  /// Throws [XmlParserException] if the file is not valid XML (T-06-S1).
  static Future<XCScheme> open(String path) async {
    final normalized = p.normalize(path);
    final content = await File(normalized).readAsString();
    final doc = XmlDocument.parse(content);
    return XCScheme._(normalized, doc);
  }

  // ---------------------------------------------------------------------------
  // Lazy action element accessors
  // ---------------------------------------------------------------------------

  /// Returns the `<BuildAction>` element, or `null` if not present.
  XmlElement? get buildActionElement => _findChild('BuildAction');

  /// Returns the `<TestAction>` element, or `null` if not present.
  XmlElement? get testActionElement => _findChild('TestAction');

  /// Returns the `<LaunchAction>` element, or `null` if not present.
  XmlElement? get launchActionElement => _findChild('LaunchAction');

  /// Returns the `<ProfileAction>` element, or `null` if not present.
  XmlElement? get profileActionElement => _findChild('ProfileAction');

  /// Returns the `<AnalyzeAction>` element, or `null` if not present.
  XmlElement? get analyzeActionElement => _findChild('AnalyzeAction');

  /// Returns the `<ArchiveAction>` element, or `null` if not present.
  XmlElement? get archiveActionElement => _findChild('ArchiveAction');

  XmlElement? _findChild(String tag) =>
      document.rootElement.findElements(tag).firstOrNull;

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  /// Returns the scheme serialized as an Xcode-formatted XML string.
  /// Uses [SchemeXmlFormatter] to produce Xcode's exact format: double-quoted
  /// XML declaration, 3-space indent, each attribute on its own
  /// line.
  String toXmlString() => SchemeXmlFormatter.format(document);

  /// SCH-03: Writes the scheme to the file at [path].
  /// Creates any missing parent directories. Updates [this.path] to [path].
  /// Throws [StateError] if the scheme was created via [create] and
  /// no path has been set yet — use [saveAs] instead.
  Future<void> save() async {
    if (_path == null) {
      throw StateError(
        'XCScheme.save() requires a path; use saveAs(path) for new schemes',
      );
    }
    await saveAs(_path!);
  }

  /// SCH-03: Writes the scheme to [path], creating parent directories as needed.
  /// Updates [this.path] to the normalized form of [path].
  Future<void> saveAs(String path) async {
    final normalized = p.normalize(path);
    await Directory(p.dirname(normalized)).create(recursive: true);
    await File(normalized).writeAsString(toXmlString());
    _path = normalized;
  }

  // ---------------------------------------------------------------------------
  // Typed action getters (SCH-04..SCH-07, )
  // These wrap the XmlElement? getters above with typed wrapper objects.
  // Existing XmlElement? getters are preserved for backward compatibility with
  // tests.
  // ---------------------------------------------------------------------------

  /// Returns a [BuildAction] wrapping the `<BuildAction>` element.
  /// If not present, creates one and appends it to the root.
  BuildAction get buildAction {
    final el = buildActionElement;
    if (el != null) return BuildAction(el);
    final created = BuildAction();
    document.rootElement.children.add(created.xmlElement);
    return BuildAction(created.xmlElement);
  }

  /// Returns a [TestAction] wrapping the `<TestAction>` element.
  /// If not present, creates one and appends it to the root.
  TestAction get testAction {
    final el = testActionElement;
    if (el != null) return TestAction(el);
    final created = TestAction();
    document.rootElement.children.add(created.xmlElement);
    return TestAction(created.xmlElement);
  }

  /// Returns a [LaunchAction] wrapping the `<LaunchAction>` element.
  /// If not present, creates one and appends it to the root.
  LaunchAction get launchAction {
    final el = launchActionElement;
    if (el != null) return LaunchAction(el);
    final created = LaunchAction();
    document.rootElement.children.add(created.xmlElement);
    return LaunchAction(created.xmlElement);
  }

  /// Returns a [ProfileAction] wrapping the `<ProfileAction>` element.
  /// If not present, creates one and appends it to the root.
  ProfileAction get profileAction {
    final el = profileActionElement;
    if (el != null) return ProfileAction(el);
    final created = ProfileAction();
    document.rootElement.children.add(created.xmlElement);
    return ProfileAction(created.xmlElement);
  }

  /// Returns an [AnalyzeAction] wrapping the `<AnalyzeAction>` element.
  /// If not present, creates one and appends it to the root.
  AnalyzeAction get analyzeAction {
    final el = analyzeActionElement;
    if (el != null) return AnalyzeAction(el);
    final created = AnalyzeAction();
    document.rootElement.children.add(created.xmlElement);
    return AnalyzeAction(created.xmlElement);
  }

  /// Returns an [ArchiveAction] wrapping the `<ArchiveAction>` element.
  /// If not present, creates one and appends it to the root.
  ArchiveAction get archiveAction {
    final el = archiveActionElement;
    if (el != null) return ArchiveAction(el);
    final created = ArchiveAction();
    document.rootElement.children.add(created.xmlElement);
    return ArchiveAction(created.xmlElement);
  }
}
