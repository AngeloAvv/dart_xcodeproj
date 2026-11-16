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
  // Typed actions
  // ---------------------------------------------------------------------------
  // Like Ruby's `XCScheme#build_action`, `#test_action`, ... the getters wrap
  // the first matching child of `<Scheme>`. A scheme that lacks the element
  // gets a default action which is *not* part of the document (so a read never
  // changes what [save] writes) until it is assigned with the setter. The
  // wrappers share the element they wrap, so edits go straight to the
  // document, and attributes and children the wrapper does not model are left
  // untouched.

  BuildAction? _detachedBuildAction;
  TestAction? _detachedTestAction;
  LaunchAction? _detachedLaunchAction;
  ProfileAction? _detachedProfileAction;
  AnalyzeAction? _detachedAnalyzeAction;
  ArchiveAction? _detachedArchiveAction;

  /// The `<BuildAction>` of this scheme.
  ///
  /// When the scheme has none, returns a default [BuildAction] that is not in
  /// the document until it is assigned to [buildAction]; the same instance is
  /// returned by every call, so edits made to it are kept. Like Ruby, a
  /// repeated element is not an error: the first one is used.
  BuildAction get buildAction {
    final el = buildActionElement;
    if (el != null) return BuildAction(el);
    return _detachedBuildAction ??= BuildAction();
  }

  /// Replaces the `<BuildAction>` of this scheme with [action].
  ///
  /// Like Ruby, the first existing `<BuildAction>` is removed and the new one
  /// is appended as the last child of `<Scheme>`. If [action] already belongs
  /// to a document, a copy of its element is inserted.
  set buildAction(BuildAction action) {
    _replaceChild(buildActionElement, action.xmlElement);
    _detachedBuildAction = null;
  }

  /// The `<TestAction>` of this scheme.
  ///
  /// When the scheme has none, returns a default [TestAction] that is not in
  /// the document until it is assigned to [testAction]; the same instance is
  /// returned by every call, so edits made to it are kept. Like Ruby, a
  /// repeated element is not an error: the first one is used.
  TestAction get testAction {
    final el = testActionElement;
    if (el != null) return TestAction(el);
    return _detachedTestAction ??= TestAction();
  }

  /// Replaces the `<TestAction>` of this scheme with [action].
  ///
  /// Like Ruby, the first existing `<TestAction>` is removed and the new one
  /// is appended as the last child of `<Scheme>`. If [action] already belongs
  /// to a document, a copy of its element is inserted.
  set testAction(TestAction action) {
    _replaceChild(testActionElement, action.xmlElement);
    _detachedTestAction = null;
  }

  /// The `<LaunchAction>` of this scheme.
  ///
  /// When the scheme has none, returns a default [LaunchAction] that is not in
  /// the document until it is assigned to [launchAction]; the same instance is
  /// returned by every call, so edits made to it are kept. Like Ruby, a
  /// repeated element is not an error: the first one is used.
  LaunchAction get launchAction {
    final el = launchActionElement;
    if (el != null) return LaunchAction(el);
    return _detachedLaunchAction ??= LaunchAction();
  }

  /// Replaces the `<LaunchAction>` of this scheme with [action].
  ///
  /// Like Ruby, the first existing `<LaunchAction>` is removed and the new one
  /// is appended as the last child of `<Scheme>`. If [action] already belongs
  /// to a document, a copy of its element is inserted.
  set launchAction(LaunchAction action) {
    _replaceChild(launchActionElement, action.xmlElement);
    _detachedLaunchAction = null;
  }

  /// The `<ProfileAction>` of this scheme.
  ///
  /// When the scheme has none, returns a default [ProfileAction] that is not
  /// in the document until it is assigned to [profileAction]; the same
  /// instance is returned by every call, so edits made to it are kept. Like
  /// Ruby, a repeated element is not an error: the first one is used.
  ProfileAction get profileAction {
    final el = profileActionElement;
    if (el != null) return ProfileAction(el);
    return _detachedProfileAction ??= ProfileAction();
  }

  /// Replaces the `<ProfileAction>` of this scheme with [action].
  ///
  /// Like Ruby, the first existing `<ProfileAction>` is removed and the new
  /// one is appended as the last child of `<Scheme>`. If [action] already
  /// belongs to a document, a copy of its element is inserted.
  set profileAction(ProfileAction action) {
    _replaceChild(profileActionElement, action.xmlElement);
    _detachedProfileAction = null;
  }

  /// The `<AnalyzeAction>` of this scheme.
  ///
  /// When the scheme has none, returns a default [AnalyzeAction] that is not
  /// in the document until it is assigned to [analyzeAction]; the same
  /// instance is returned by every call, so edits made to it are kept. Like
  /// Ruby, a repeated element is not an error: the first one is used.
  AnalyzeAction get analyzeAction {
    final el = analyzeActionElement;
    if (el != null) return AnalyzeAction(el);
    return _detachedAnalyzeAction ??= AnalyzeAction();
  }

  /// Replaces the `<AnalyzeAction>` of this scheme with [action].
  ///
  /// Like Ruby, the first existing `<AnalyzeAction>` is removed and the new
  /// one is appended as the last child of `<Scheme>`. If [action] already
  /// belongs to a document, a copy of its element is inserted.
  set analyzeAction(AnalyzeAction action) {
    _replaceChild(analyzeActionElement, action.xmlElement);
    _detachedAnalyzeAction = null;
  }

  /// The `<ArchiveAction>` of this scheme.
  ///
  /// When the scheme has none, returns a default [ArchiveAction] that is not
  /// in the document until it is assigned to [archiveAction]; the same
  /// instance is returned by every call, so edits made to it are kept. Like
  /// Ruby, a repeated element is not an error: the first one is used.
  ArchiveAction get archiveAction {
    final el = archiveActionElement;
    if (el != null) return ArchiveAction(el);
    return _detachedArchiveAction ??= ArchiveAction();
  }

  /// Replaces the `<ArchiveAction>` of this scheme with [action].
  ///
  /// Like Ruby, the first existing `<ArchiveAction>` is removed and the new
  /// one is appended as the last child of `<Scheme>`. If [action] already
  /// belongs to a document, a copy of its element is inserted.
  set archiveAction(ArchiveAction action) {
    _replaceChild(archiveActionElement, action.xmlElement);
    _detachedArchiveAction = null;
  }

  void _replaceChild(XmlElement? existing, XmlElement replacement) {
    existing?.remove();
    document.rootElement.children.add(
      replacement.parent == null ? replacement : replacement.copy(),
    );
  }
}
