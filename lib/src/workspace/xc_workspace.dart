// Provides support for generating, reading, and serializing Xcode Workspace
// documents (contents.xcworkspacedata).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'file_reference.dart';
import 'group_reference.dart';
import 'workspace_reference.dart';

/// Read/write support for `.xcworkspace/contents.xcworkspacedata` files.
/// ## Usage
/// ```dart
/// // Open an existing workspace
/// final ws = await XCWorkspace.open('MyApp.xcworkspace');
/// print(ws.fileReferences.map((r) => r.path)); // ['MyApp.xcodeproj', ...]
/// ws.schemes.forEach((name, path) => print('$name → $path'));
/// // Create a new empty workspace
/// final ws = XCWorkspace.create('NewApp.xcworkspace');
/// await ws.save();
/// ```
/// Security (T-06-W3): malformed XML in `contents.xcworkspacedata` causes
/// [XmlParserException] to propagate from [open]. Callers should catch it.
class XCWorkspace {
  /// The normalized absolute path to the `.xcworkspace` directory.
  final String path;

  /// Top-level references in the workspace (both [WorkspaceFileReference] and
  /// [WorkspaceGroupReference]).
  final List<WorkspaceReference> rootReferences;

  /// Map of scheme name → container directory path.
  /// Populated at [open] time by scanning `xcshareddata/xcschemes/*.xcscheme`
  /// inside the workspace directory. Does NOT include project-internal schemes
  /// (matches Ruby `Workspace#load_schemes` behavior — Open Question 2).
  /// Returns [Map]`<String, String>` (NOT [XCScheme] objects — Pattern 7).
  final Map<String, String> schemes;

  XCWorkspace._(this.path, this.rootReferences, this.schemes);

  // ---------------------------------------------------------------------------
  // Factory constructors
  // ---------------------------------------------------------------------------

  /// WORK-01: Creates a new empty workspace at [path].
  /// Returns an [XCWorkspace] with no file/group references and an empty
  /// [schemes] map. Call [save] to write the initial `contents.xcworkspacedata`.
  static XCWorkspace create(String path) => XCWorkspace._(
    p.normalize(path),
    <WorkspaceReference>[],
    <String, String>{},
  );

  /// WORK-02: Opens an existing workspace by reading `{path}/contents.xcworkspacedata`.
  /// Parses `<FileRef>` and `<Group>` elements recursively. Also scans
  /// `{path}/xcshareddata/xcschemes/*.xcscheme` to populate [schemes].
  /// Throws [FileSystemException] if `contents.xcworkspacedata` does not exist.
  /// Throws [XmlParserException] (T-06-W3) if the XML is malformed.
  static Future<XCWorkspace> open(String path) async {
    final normalized = p.normalize(path);
    final contentsPath = p.join(normalized, 'contents.xcworkspacedata');
    final file = File(contentsPath);
    if (!file.existsSync()) {
      throw FileSystemException(
        'Workspace contents file not found',
        contentsPath,
      );
    }
    final content = await file.readAsString();
    final doc = XmlDocument.parse(content);
    final root = doc.rootElement; // <Workspace>
    final refs = <WorkspaceReference>[];
    for (final child in root.childElements) {
      final parsed = _parseReference(child);
      if (parsed != null) refs.add(parsed);
    }
    final schemes = _loadSchemes(normalized);
    return XCWorkspace._(normalized, refs, schemes);
  }

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  /// Top-level [WorkspaceFileReference] entries only (not nested).
  Iterable<WorkspaceFileReference> get fileReferences =>
      rootReferences.whereType<WorkspaceFileReference>();

  /// Top-level [WorkspaceGroupReference] entries only (not nested).
  Iterable<WorkspaceGroupReference> get groupReferences =>
      rootReferences.whereType<WorkspaceGroupReference>();

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  /// WORK-03: Writes `contents.xcworkspacedata` to disk.
  /// Creates the workspace directory if it does not exist.
  /// Output uses Xcode's exact format: 3-space indent per depth level,
  /// each attribute on its own line, producing a byte-identical round-trip
  /// for workspaces read with [open].
  Future<void> save() async {
    await Directory(path).create(recursive: true);
    final contentsPath = p.join(path, 'contents.xcworkspacedata');
    await File(contentsPath).writeAsString(_buildXml());
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Parses a single `<FileRef>` or `<Group>` XML element.
  static WorkspaceReference? _parseReference(XmlElement el) {
    switch (el.name.local) {
      case 'FileRef':
        final loc = el.getAttribute('location') ?? '';
        return WorkspaceFileReference.fromLocation(loc);

      case 'Group':
        final loc = el.getAttribute('location') ?? 'container:';
        final name = el.getAttribute('name') ?? '';
        final locIdx = loc.indexOf(':');
        final type = locIdx >= 0 ? loc.substring(0, locIdx) : 'container';
        final groupPath = locIdx >= 0 ? loc.substring(locIdx + 1) : loc;
        final children = <WorkspaceReference>[];
        for (final c in el.childElements) {
          final parsed = _parseReference(c);
          if (parsed != null) children.add(parsed);
        }
        return WorkspaceGroupReference(
          type: type,
          path: groupPath,
          name: name,
          children: children,
        );

      default:
        return null;
    }
  }

  /// WORK-05: Scans `{workspacePath}/xcshareddata/xcschemes/*.xcscheme`.
  /// Returns a map of scheme name → absolute workspace path.
  /// Does NOT scan project FileRefs for nested schemes — matches Ruby
  /// `Workspace#load_schemes` workspace-container portion (Open Question 2
  /// resolved: user schemes in `xcuserdata/` are excluded by design).
  static Map<String, String> _loadSchemes(String workspacePath) {
    final out = <String, String>{};
    final dir = Directory(p.join(workspacePath, 'xcshareddata', 'xcschemes'));
    if (!dir.existsSync()) return out;
    for (final entry in dir.listSync()) {
      if (entry is File && p.extension(entry.path) == '.xcscheme') {
        out[p.basenameWithoutExtension(entry.path)] = p.normalize(
          p.absolute(workspacePath),
        );
      }
    }
    return out;
  }

  /// Builds the `contents.xcworkspacedata` XML string in Xcode's exact format.
  /// Format (Pattern 3 / `root_xml` + `xcworkspace_element_start_xml`):
  /// ```
  /// <?xml version="1.0" encoding="UTF-8"?>
  /// <Workspace
  /// version = "1.0">
  /// <FileRef
  /// location = "group:App.xcodeproj">
  /// </FileRef>
  /// </Workspace>
  /// ```
  String _buildXml() {
    final buf = StringBuffer();
    buf.write('<?xml version="1.0" encoding="UTF-8"?>\n');
    buf.write('<Workspace\n');
    buf.write('   version = "1.0">\n');
    for (final ref in rootReferences) {
      buf.write(ref.toXmlFragment(1));
      buf.write('\n');
    }
    buf.write('</Workspace>\n');
    return buf.toString();
  }
}
