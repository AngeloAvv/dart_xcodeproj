// This is the public container class implementing [ObjectGraph].
// It is the entry point for all downstream helpers (ProjectHelper,
// FileReferencesFactory, deferred helpers in ).
// Security: — save() uses p.normalize; writes ONLY to
// p.join(path, 'project.pbxproj') — never outside the bundle.

import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;

import '../constants/build_settings.dart';
import '../constants/object_versions.dart';
import '../object/abstract_object.dart';
import '../object/isa_registry.dart';
import '../object/object_graph.dart';
import '../object/object_list.dart';
import '../pbx/group.dart';
import '../pbx/pbx_file_reference.dart';
import '../pbx/pbx_native_target.dart';
import 'file_references_factory.dart';
import 'groups_position.dart';
import '../pbx/pbx_project.dart';
import '../pbx/xc_build_configuration.dart';
import '../pbx/xc_configuration_list.dart';
import '../plist/ascii_plist_writer.dart';
import '../plist/plist_reader.dart';
import 'uuid_generator.dart';

/// Whether a build configuration is a debug or release variant.
/// Used by [XcodeProject.addBuildConfiguration] to select the appropriate
/// subset of [BuildSettings.projectDefaultBuildSettings] to apply.
enum BuildConfigType { debug, release }

/// The public container class for an Xcode project.
/// Implements [ObjectGraph] and exposes the open/create/save lifecycle plus
/// all convenience accessors required by downstream helpers.
/// Port of Ruby [Xcodeproj::Project].
/// Lifecycle:
/// - [XcodeProject.open] — load an existing `.xcodeproj` from disk.
/// - [XcodeProject.create] — create a new project from scratch.
/// - [save] — write `project.pbxproj` to the `.xcodeproj` bundle.
/// Security: — [save] writes ONLY inside the `.xcodeproj` bundle.
class XcodeProject implements ObjectGraph {
  /// Path to the `.xcodeproj` bundle directory.
  final String path;

  /// The directory containing the `.xcodeproj` bundle.
  String get projectDir => p.dirname(path);

  /// Project name derived from the `.xcodeproj` bundle basename.
  /// Port of Ruby `project.path.basename('.xcodeproj').to_s`.
  /// PBXProject does NOT serialize a 'name' attribute.
  String get name => p.basenameWithoutExtension(path);

  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------

  String _archiveVersion = ObjectVersions.lastKnownArchiveVersion.toString();
  String _objectVersion = ObjectVersions.defaultObjectVersion.toString();
  Map<String, dynamic> _classes = {};

  /// Exposes the plist object version for use by [XCBuildConfiguration._normalizeArraySettings].
  /// Implements [ObjectGraph.objectVersion] — allows /4 objects to access
  /// the project's objectVersion without importing xcode_project.dart.
  @override
  String get objectVersion => _objectVersion;

  @override
  final Map<String, AbstractObject> objectsByUuid = <String, AbstractObject>{};

  PBXProject? _rootObject;

  /// The root PBXProject object. Throws if not set (never null after open/create).
  PBXProject get rootObject => _rootObject!;

  /// UUIDs that have been generated in this session (collision avoidance).
  final List<String> _generatedUuids = [];

  /// UUIDs available for assignment (pre-generated batch).
  final List<String> _availableUuids = [];

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  XcodeProject._(this.path);

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  /// Loads an existing `.xcodeproj` from [path] and returns an [XcodeProject].
  /// [path] must end with `.xcodeproj`. The `project.pbxproj` file inside the
  /// bundle is parsed and all PBX objects are deserialized into [objectsByUuid].
  /// Emits `developer.log` warnings (never throws) for unknown archive/object
  /// versions.
  /// Port of Ruby `Xcodeproj::Project.open`.
  static Future<XcodeProject> open(String path) async {
    if (!path.endsWith('.xcodeproj')) {
      throw ArgumentError(
        'path must point to a .xcodeproj directory, got: $path',
      );
    }

    // normalize path before constructing pbxprojPath.
    final normalizedPath = p.normalize(path);
    final pbxprojPath = p.join(normalizedPath, 'project.pbxproj');

    // Populate ISA registry so all + types deserialize.
    registerPhase3Types();
    registerPhase4Types();

    final plist = PlistReader.readFromPath(pbxprojPath);

    final project = XcodeProject._(normalizedPath);
    project._archiveVersion = plist['archiveVersion'] is String
        ? plist['archiveVersion'] as String
        : '1';
    project._objectVersion = plist['objectVersion'] is String
        ? plist['objectVersion'] as String
        : '46';
    project._classes =
        (plist['classes'] as Map?)?.cast<String, dynamic>() ?? {};

    final rootUuidRaw = plist['rootObject'];
    if (rootUuidRaw is! String) {
      throw const FormatException(
        'project.pbxproj: missing or non-string rootObject key',
      );
    }
    final rootUuid = rootUuidRaw;
    final objectsPlist = (plist['objects'] as Map).cast<String, dynamic>();

    // Deserialize all objects (register-before-configure per ).
    for (final uuid in objectsPlist.keys) {
      if (!project.objectsByUuid.containsKey(uuid)) {
        objectFromPlist(uuid, objectsPlist, project);
      }
    }

    // Locate the root PBXProject.
    final root = project.objectsByUuid[rootUuid];
    if (root is! PBXProject) {
      throw FormatException(
        'project.pbxproj: rootObject "$rootUuid" is not a PBXProject '
        '(found: ${root?.isa ?? "missing"})',
      );
    }
    project._rootObject = root;
    // rootObject referrer must be the XcodeProject container itself.
    root.addReferrer(project);

    // Version warnings.
    final archiveVersion = int.tryParse(project._archiveVersion) ?? 0;
    final objectVersion = int.tryParse(project._objectVersion) ?? 0;
    if (archiveVersion > ObjectVersions.lastKnownArchiveVersion) {
      developer.log(
        '[dart_xcodeproj] Archive version $archiveVersion higher than supported '
        '(${ObjectVersions.lastKnownArchiveVersion}). Some data may be unreadable.',
        name: 'dart_xcodeproj',
      );
    }
    if (objectVersion > ObjectVersions.lastKnownObjectVersion) {
      developer.log(
        '[dart_xcodeproj] Object version $objectVersion higher than supported '
        '(${ObjectVersions.lastKnownObjectVersion}). Some data may be unreadable.',
        name: 'dart_xcodeproj',
      );
    }

    return project;
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  /// Creates a new Xcode project at [path] and returns an [XcodeProject].
  /// Replicates Ruby's `initialize_from_scratch`:
  /// wires PBXProject → mainGroup → productsGroup + frameworksGroup +
  /// XCConfigurationList with Debug and Release configurations.
  /// Does NOT write to disk — call [save] to persist.
  /// Port of Ruby `Xcodeproj::Project.new` with `initialize_from_scratch`
  static Future<XcodeProject> create(String path) async {
    if (!path.endsWith('.xcodeproj')) {
      throw ArgumentError(
        'path must point to a .xcodeproj directory, got: $path',
      );
    }

    // normalize path for consistency with open().
    final normalizedPath = p.normalize(path);

    registerPhase3Types();
    registerPhase4Types();

    final project = XcodeProject._(normalizedPath);
    project._archiveVersion = ObjectVersions.lastKnownArchiveVersion.toString();
    project._objectVersion = ObjectVersions.defaultObjectVersion.toString();
    project._classes = {};

    // 1. Create PBXProject root object (addReferrer with the container).
    final pbxProject = project.newObject((g, u) => PBXProject(g, u));
    project._rootObject = pbxProject;
    pbxProject.addReferrer(project);

    // 2. Create main group.
    final mainGroup = project.newObject((g, u) => PBXGroup(g, u));
    pbxProject.mainGroup =
        mainGroup; // triggers mainGroup.addReferrer(pbxProject)

    // 3. Create Products group and wire as child + productRefGroup.
    final productsGroup = project.newObject((g, u) => PBXGroup(g, u));
    productsGroup.name = 'Products';
    productsGroup.sourceTree = '<group>';
    mainGroup.children.add(productsGroup);
    pbxProject.productRefGroup = productsGroup;

    // 4. Create XCConfigurationList.
    final configList = project.newObject((g, u) => XCConfigurationList(g, u));
    configList.defaultConfigurationName = 'Release';
    configList.defaultConfigurationIsVisible = '0';
    pbxProject.buildConfigurationList = configList;

    // 5. Add Debug and Release build configurations.
    project.addBuildConfiguration('Debug', BuildConfigType.debug);
    project.addBuildConfiguration('Release', BuildConfigType.release);

    // 6. Create Frameworks group.
    final frameworksGroup = project.newObject((g, u) => PBXGroup(g, u));
    frameworksGroup.name = 'Frameworks';
    frameworksGroup.sourceTree = '<group>';
    mainGroup.children.add(frameworksGroup);

    // 7. Set compatibility version from object version (fallback: 'Xcode 3.2').
    pbxProject.compatibilityVersion =
        ObjectVersions.compatibilityVersionByObjectVersion[ObjectVersions
            .defaultObjectVersion] ??
        'Xcode 3.2';

    return project;
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  /// Saves the project to `<path>/project.pbxproj`.
  /// Creates the `.xcodeproj` bundle directory if it does not exist.
  /// Objects are sorted by `[isa, uuid]` before serialization.
  /// Security: — writes ONLY to `p.join(path, 'project.pbxproj')`.
  /// `p.normalize(path)` is already applied at construction time for open();
  /// for create() paths, normalize here.
  /// Port of Ruby `Xcodeproj::Project#save`.
  Future<void> save() async {
    // ensure we write only inside the bundle.
    final normalizedPath = p.normalize(path);
    final pbxprojPath = p.join(normalizedPath, 'project.pbxproj');
    await Directory(normalizedPath).create(recursive: true);
    final content = _toAsciiPlist();
    await File(pbxprojPath).writeAsString(content);
  }

  // ---------------------------------------------------------------------------
  // ObjectGraph contract
  // ---------------------------------------------------------------------------

  /// Mark the project as having unsaved changes. No-op.
  @override
  void markDirty() {
    /* no-op — defers dirty tracking */
  }

  /// Create a new object, assign a UUID, call `initializeDefaults()`.
  /// Does NOT register in [objectsByUuid] — registration happens via
  /// [AbstractObject.addReferrer] when the new object is first wired.
  /// Port of Ruby `project.new_object`.
  @override
  T newObject<T extends AbstractObject>(
    T Function(ObjectGraph, String) factory,
  ) {
    final uuid = generateUuid();
    final obj = factory(this, uuid);
    obj.initializeDefaults();
    return obj;
  }

  // ---------------------------------------------------------------------------
  // UUID generation
  // ---------------------------------------------------------------------------

  /// Generates a unique 24-char uppercase hex UUID for this project.
  /// Internally maintains a batch to avoid UUID collisions within a session.
  String generateUuid() {
    while (_availableUuids.isEmpty) {
      _generateBatch();
    }
    return _availableUuids.removeAt(0);
  }

  void _generateBatch() {
    String uuid;
    do {
      uuid = UuidGenerator.generate();
    } while (_generatedUuids.contains(uuid));
    _generatedUuids.add(uuid);
    _availableUuids.add(uuid);
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  /// The main project navigator group (port of `project.main_group`).
  PBXGroup get mainGroup => _rootObject!.mainGroup!;

  /// All build targets in this project.
  ObjectList<AbstractTarget> get targets => _rootObject!.targets;

  /// All PBXFileReference objects in the project (flat list).
  List<PBXFileReference> get files =>
      objectsByUuid.values.whereType<PBXFileReference>().toList();

  /// All PBXGroup objects in the project (flat list).
  List<PBXGroup> get groups =>
      objectsByUuid.values.whereType<PBXGroup>().toList();

  /// The products group (usually named 'Products').
  PBXGroup get productsGroup => _rootObject!.productRefGroup!;

  /// The root XCConfigurationList for the project.
  XCConfigurationList get buildConfigurationList =>
      _rootObject!.buildConfigurationList!;

  /// All XCBuildConfiguration objects in the root XCConfigurationList.
  List<XCBuildConfiguration> get buildConfigurations =>
      buildConfigurationList.buildConfigurations.toList();

  /// Build settings for the named configuration, or null if not found.
  Map<String, dynamic>? buildSettings(String configName) =>
      buildConfigurationList[configName]?.buildSettings;

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  /// Adds a new file reference to [mainGroup] and returns it.
  /// Delegates to [FileReferencesFactory.newReference]. The returned object is
  /// a [PBXFileReference] for most paths; an [XCVersionGroup] for .xcdatamodeld.
  /// Port of Ruby `project.new_file` convenience helper.
  PBXFileReference newFile(String refPath, {String sourceTree = '<group>'}) {
    final ref = FileReferencesFactory.newReference(
      mainGroup,
      refPath,
      sourceTree,
    );
    if (ref is! PBXFileReference) {
      throw ArgumentError(
        'newFile: path "$refPath" produced a ${ref.isa}, not a PBXFileReference. '
        'Use newReference() for .xcdatamodeld paths.',
      );
    }
    return ref;
  }

  /// Adds a new group to [mainGroup] and returns it.
  /// Port of Ruby `project.new_group` convenience helper.
  PBXGroup newGroup(
    String name, {
    String? path,
    String sourceTree = '<group>',
  }) {
    final grp = newObject((g, u) => PBXGroup(g, u));
    grp.name = name;
    grp.path = path;
    grp.sourceTree = sourceTree;
    mainGroup.children.add(grp);
    return grp;
  }

  // ---------------------------------------------------------------------------
  // addBuildConfiguration — PROJ-04 (idempotent)
  // ---------------------------------------------------------------------------

  /// Adds a new build configuration named [name] to the root
  /// [buildConfigurationList]. If a configuration with [name] already exists,
  /// returns the existing one (idempotent — ).
  /// [type] selects which subset of [BuildSettings.projectDefaultBuildSettings]
  /// to apply: `'all'` keys are always applied; `type.name` keys are overlaid.
  /// Port of Ruby `project.add_build_configuration`.
  XCBuildConfiguration addBuildConfiguration(
    String name,
    BuildConfigType type,
  ) {
    final list = _rootObject!.buildConfigurationList!;
    final existing = list[name];
    if (existing != null) return existing; // idempotent
    final config = newObject((g, u) => XCBuildConfiguration(g, u));
    config.name = name;

    final commonSettings = BuildSettings.projectDefaultBuildSettings;
    final settings = Map<String, dynamic>.from(
      (commonSettings['all'] ?? const {}) as Map,
    );
    settings.addAll(
      Map<String, dynamic>.from((commonSettings[type.name] ?? const {}) as Map),
    );
    config.buildSettings = settings;
    list.buildConfigurations.add(config);
    return config;
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  /// Sorts the project hierarchy starting from [mainGroup].
  /// [groupsPosition] controls whether groups appear above or below files:
  /// - [GroupsPosition.above]: groups before files in each group.
  /// - [GroupsPosition.below]: files before groups in each group.
  /// - null (default): groups and files sorted together by name.
  /// Sort is recursive — all nested groups are also sorted.
  /// Port of Ruby `project.sort(options)`.
  void sort({GroupsPosition? groupsPosition}) {
    _rootObject!.sortRecursively(groupsPosition: groupsPosition);
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------

  /// Returns a Map representation of the project (plist-equivalent structure).
  /// Top-level keys: 'objects', 'archiveVersion', 'objectVersion', 'classes',
  /// 'rootObject' (UUID string).
  /// Port of Ruby `project.to_hash`.
  Map<String, dynamic> toHash() {
    final objectsDict = <String, dynamic>{};
    for (final obj in objectsByUuid.values) {
      objectsDict[obj.uuid] = obj.toHash();
    }
    return {
      'objects': objectsDict,
      'archiveVersion': _archiveVersion,
      'objectVersion': _objectVersion,
      'classes': _classes,
      'rootObject': _rootObject!.uuid,
    };
  }

  /// Returns a tree-expanded Map where 'rootObject' is inline (not a UUID string).
  /// 'objects' is intentionally empty — the root expands inline per Ruby behavior.
  /// Port of Ruby `project.to_tree_hash`.
  Map<String, dynamic> toTreeHash() {
    return {
      'objects': <String, dynamic>{},
      'archiveVersion': _archiveVersion,
      'objectVersion': _objectVersion,
      'classes': _classes,
      'rootObject': _rootObject!.toTreeHash(),
    };
  }

  /// Returns a human-readable summary of the project structure.
  /// Keys: 'File References', 'Targets', 'Build Configurations'.
  /// Port of Ruby `project.pretty_print`.
  Map<String, dynamic> prettyPrint() {
    final configs =
        _rootObject!.buildConfigurationList!.buildConfigurations.toList()
          ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
    final mainGroupPP = _rootObject!.mainGroup!.prettyPrint();
    final fileRefsValue = mainGroupPP is Map
        ? mainGroupPP.values.first
        : mainGroupPP;
    return {
      'File References': fileRefsValue,
      'Targets': _rootObject!.targets.map((t) => t.prettyPrint()).toList(),
      'Build Configurations': configs.map((c) => c.prettyPrint()).toList(),
    };
  }

  // ---------------------------------------------------------------------------
  // Serialization helpers
  // ---------------------------------------------------------------------------

  /// Converts the object graph to Apple ASCII plist text.
  /// Objects are sorted by [isa, uuid] (RESEARCH Pattern 3, ) before
  /// being passed to [AsciiPlistWriter.write].
  /// Port of Ruby `project.to_ascii_plist`.
  String _toAsciiPlist() {
    // Sort objects by [isa, uuid].
    final sorted = objectsByUuid.values.toList()
      ..sort((a, b) {
        final c = a.isa.compareTo(b.isa);
        return c != 0 ? c : a.uuid.compareTo(b.uuid);
      });

    // Build the objects map (sorted insertion order = serialization order).
    final objectsMap = <String, dynamic>{};
    for (final obj in sorted) {
      objectsMap[obj.uuid] = obj.toHash();
    }

    // Build top-level plist with EXACT key order (insertion order preserved in
    // Dart LinkedHashMap / Map literal).
    final plistMap = <String, dynamic>{
      'archiveVersion': _archiveVersion,
      'classes': _classes,
      'objectVersion': _objectVersion,
      'objects': objectsMap,
      'rootObject': _rootObject!.uuid,
    };

    return AsciiPlistWriter().write(plistMap);
  }
}
