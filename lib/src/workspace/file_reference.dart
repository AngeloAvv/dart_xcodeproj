// Represents a <FileRef> element inside contents.xcworkspacedata.

import 'package:path/path.dart' as p;

import 'workspace_reference.dart';

/// A workspace reference to a single file (typically an `.xcodeproj`).
/// The [location] attribute has the form `'type:path'`, where type is one of
/// `group`, `container`, `absolute`, `self`, or `developer`.
class WorkspaceFileReference extends WorkspaceReference {
  @override
  final String type;

  @override
  final String path;

  /// Creates a file reference with the given [type] and [path].
  WorkspaceFileReference({required this.type, required this.path});

  /// Parses a `'type:path'` [location] string.
  /// If no colon is present, defaults to type `'group'` with the entire
  /// string as the path.
  factory WorkspaceFileReference.fromLocation(String location) {
    final idx = location.indexOf(':');
    if (idx < 0) {
      return WorkspaceFileReference(type: 'group', path: location);
    }
    return WorkspaceFileReference(
      type: location.substring(0, idx),
      path: location.substring(idx + 1),
    );
  }

  /// Returns the absolute path for this reference given [workspaceDir].
  /// Implements — 4 cases:
  /// - `group`, `container`, `self` → path relative to [workspaceDir]
  /// - `absolute` → path is already absolute ([workspaceDir] ignored)
  /// - `developer` → throws [UnsupportedError]
  /// Security (T-06-W1): callers should validate returned paths before
  /// opening files from untrusted workspaces.
  String absolutePath(String workspaceDir) {
    switch (type) {
      case 'group':
      case 'container':
      case 'self':
        return p.normalize(p.absolute(p.join(workspaceDir, path)));
      case 'absolute':
        return p.normalize(p.absolute(path));
      case 'developer':
        throw UnsupportedError(
          'Developer-relative workspace paths are not supported (path: $path)',
        );
      default:
        throw ArgumentError('Unknown WorkspaceFileReference type: $type');
    }
  }

  /// Serializes as a `<FileRef>` XML fragment.
  /// Attribute order: `location` only ( — matches Xcode output).
  /// Uses 3-space indent per [depth] level; attributes indented 3 more spaces.
  @override
  String toXmlFragment(int depth) {
    final pad = ' ' * (depth * 3);
    final attrPad = ' ' * (depth * 3 + 3);
    final buf = StringBuffer();
    buf.write('$pad<FileRef\n');
    buf.write(
      '$attrPad'
      'location = "$location">\n',
    );
    buf.write('$pad</FileRef>');
    return buf.toString();
  }
}
