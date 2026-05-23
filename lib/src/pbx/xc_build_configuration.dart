import '../constants/misc.dart';
import '../object/abstract_object.dart';
import 'pbx_file_reference.dart';

/// Represents a named build configuration (Debug/Release) in an Xcode project.
/// Port of [XCBuildConfiguration]. Holds a [buildSettings]
/// map, an optional [baseConfigurationReference] to an xcconfig file, and a
/// [resolveBuildSetting] engine that recursively expands `${VAR}`/`$(VAR)` syntax,
/// handles `$(inherited)` chaining, and guards against mutual recursion.
/// Key contracts:
/// - [buildSettings] is always serialized even when empty.
/// - [_normalizeArraySettings] is applied to a COPY of buildSettings on write;
/// the in-memory model is never mutated by serialization.
/// - [resolveBuildSetting] mutual-recursion protection via [_kMutualRecursionSentinel].
class XCBuildConfiguration extends AbstractObject {
  // ---------------------------------------------------------------------------
  // Sentinel + regex
  // ---------------------------------------------------------------------------

  /// Sentinel returned when a mutual-recursion cycle is detected.
  /// Converted to null by [resolveBuildSetting] post-processing.
  /// Port of: MUTUAL_RECURSION_SENTINEL
  static const String _kMutualRecursionSentinel =
      'xcodeproj.mutual_recursion_sentinel';

  /// Regex capturing `${VARNAME}` or `$(VARNAME)` variable references.
  /// Port of: CAPTURE_VARIABLE_IN_BUILD_CONFIG
  static final RegExp _captureVariable = RegExp(
    r'\$(?:\{([_a-zA-Z0-9]+?)\}|\(([_a-zA-Z0-9]+?)\))',
  );

  // ---------------------------------------------------------------------------
  // ISA
  // ---------------------------------------------------------------------------

  static const String isaStatic = 'XCBuildConfiguration';

  // ---------------------------------------------------------------------------
  // ARRAY_SETTINGS — keys whose values are stored as arrays of strings.
  // ---------------------------------------------------------------------------

  /// Default set — object_version < 50 (Xcode < 10). 17 items.
  static const Set<String> _arraySettingsDefault = {
    'ALTERNATE_PERMISSIONS_FILES',
    'ARCHS',
    'BUILD_VARIANTS',
    'EXCLUDED_SOURCE_FILE_NAMES',
    'FRAMEWORK_SEARCH_PATHS',
    'GCC_PREPROCESSOR_DEFINITIONS',
    'GCC_PREPROCESSOR_DEFINITIONS_NOT_USED_IN_PRECOMPS',
    'HEADER_SEARCH_PATHS',
    'INFOPLIST_PREPROCESSOR_DEFINITIONS',
    'LIBRARY_SEARCH_PATHS',
    'OTHER_CFLAGS',
    'OTHER_CPLUSPLUSFLAGS',
    'OTHER_LDFLAGS',
    'REZ_SEARCH_PATHS',
    'SECTORDER_FLAGS',
    'WARNING_CFLAGS',
    'WARNING_LDFLAGS',
  };

  /// Extended set — object_version >= 50 (Xcode 10+). Adds 6 more items.
  static const Set<String> _arraySettingsV50 = {
    ..._arraySettingsDefault,
    'INCLUDED_SOURCE_FILE_NAMES',
    'LD_RUNPATH_SEARCH_PATHS',
    'LOCALIZED_STRING_MACRO_NAMES',
    'SYSTEM_FRAMEWORK_SEARCH_PATHS',
    'SYSTEM_HEADER_SEARCH_PATHS',
    'USER_HEADER_SEARCH_PATHS',
  };

  /// Pick the correct ARRAY_SETTINGS set based on the project's object_version.
  /// will wire in the real objectVersion via the project graph.
  /// passes null → uses [_arraySettingsDefault].
  Set<String> _arraySettingsFor(String? objectVersion) {
    final v = int.tryParse(objectVersion ?? '') ?? 0;
    return v >= 50 ? _arraySettingsV50 : _arraySettingsDefault;
  }

  // ---------------------------------------------------------------------------
  // Attribute key constants
  // ---------------------------------------------------------------------------

  static const String _kName = 'name';
  static const String _kBuildSettings = 'buildSettings';
  static const String _kBaseConfigurationReference =
      'baseConfigurationReference';
  static const String _kBaseConfigurationReferenceAnchor =
      'baseConfigurationReferenceAnchor';
  static const String _kBaseConfigurationReferenceRelativePath =
      'baseConfigurationReferenceRelativePath';

  static const List<String> _ownAttributes = [
    _kName,
    _kBuildSettings,
    _kBaseConfigurationReference,
    _kBaseConfigurationReferenceAnchor,
    _kBaseConfigurationReferenceRelativePath,
  ];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// The configuration name (e.g., 'Debug' or 'Release').
  String? name;

  /// Build settings dictionary. Non-nullable — always serialized even when empty.
  /// Port of attribute :build_settings, Hash, default: {}
  Map<String, dynamic> buildSettings = {};

  /// Optional reference to an xcconfig file that provides base settings.
  /// Ref-counted with identity-guard setter.
  PBXFileReference? _baseConfigurationReference;

  PBXFileReference? get baseConfigurationReference =>
      _baseConfigurationReference;

  set baseConfigurationReference(PBXFileReference? value) {
    if (identical(_baseConfigurationReference, value)) return;
    markProjectAsDirty();
    _baseConfigurationReference?.removeReferrer(this);
    _baseConfigurationReference = value;
    value?.addReferrer(this);
  }

  /// Optional anchor object for the base configuration reference ( type).
  /// Declared as AbstractObject? — concrete type wired later.
  AbstractObject? _baseConfigurationReferenceAnchor;

  AbstractObject? get baseConfigurationReferenceAnchor =>
      _baseConfigurationReferenceAnchor;

  set baseConfigurationReferenceAnchor(AbstractObject? value) {
    if (identical(_baseConfigurationReferenceAnchor, value)) return;
    markProjectAsDirty();
    _baseConfigurationReferenceAnchor?.removeReferrer(this);
    _baseConfigurationReferenceAnchor = value;
    value?.addReferrer(this);
  }

  /// Optional relative path string for the base configuration reference.
  /// Plain String — no ref counting.
  String? baseConfigurationReferenceRelativePath;

  // ---------------------------------------------------------------------------
  // : xcconfig integration
  // ---------------------------------------------------------------------------

  /// Pre-loaded xcconfig attributes injected by [XcodeProject] when
  /// [baseConfigurationReference] can be resolved on disk.
  /// Consumed by [resolveBuildSetting] as a resolution layer between
  /// project-level settings and in-map [buildSettings].
  /// (): set by calling [setLoadedXcConfig].
  Map<String, String>? _loadedXcConfigSettings;

  /// (): inject pre-loaded xcconfig attributes for resolveBuildSetting.
  /// Called by XcodeProject when baseConfigurationReference can be resolved on disk.
  void setLoadedXcConfig(Map<String, String>? settings) {
    _loadedXcConfigSettings = settings;
  }

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  XCBuildConfiguration(super.project, super.uuid);

  // ---------------------------------------------------------------------------
  // AbstractObject overrides
  // ---------------------------------------------------------------------------

  @override
  String get isa => isaStatic;

  @override
  void initializeDefaults() {
    buildSettings = {}; // fresh map per instance
  }

  @override
  List<String> get attributeOrder => [
    ..._ownAttributes,
    ...super.attributeOrder,
  ];

  // ---------------------------------------------------------------------------
  // normalizeArraySettings helpers (private)
  // ---------------------------------------------------------------------------

  /// Normalize build settings array values for round-trip fidelity.
  /// Mutates [settings] in place. Caller must pass a COPY of [buildSettings]
  /// so the in-memory model is not affected.
  /// Rules (ported from):
  /// - String value + key in ARRAY_SETTINGS + &gt; 1 token → split to `List<String>`
  /// - List value + key NOT in ARRAY_SETTINGS (or single-item) → join to String
  void _normalizeArraySettings(Map<String, dynamic> settings) {
    // : use the project's actual objectVersion for correct ARRAY_SETTINGS selection.
    // For objectVersion >= 50 (Xcode 10+), LD_RUNPATH_SEARCH_PATHS and others are arrays.
    final arraySettings = _arraySettingsFor(project.objectVersion);
    final keys = settings.keys
        .toList(); // snapshot to avoid concurrent modification
    for (final key in keys) {
      final value = settings[key];
      if (value == null) continue;
      // Strip conditional SDK suffix: 'OTHER_LDFLAGS[sdk=iphonesimulator*]' → 'OTHER_LDFLAGS'
      final strippedKey = key.replaceAll(RegExp(r'\[[^\]]+\]$'), '');
      if (value is String) {
        if (!arraySettings.contains(strippedKey)) continue;
        final parts = _splitBuildSettingString(value);
        if (parts.length <= 1) continue; // single token: leave as String
        settings[key] = parts;
      } else if (value is List) {
        if (arraySettings.contains(strippedKey))
          continue; // preserve all lists for array keys
        settings[key] = value.join(' '); // collapse to String
      }
    }
  }

  /// Split a build setting string on whitespace, respecting non-empty tokens.
  /// Port of Ruby's split_build_setting_array_to_string.
  /// : simple whitespace split — sufficient for all ARRAY_SETTINGS values.
  List<String> _splitBuildSettingString(String s) {
    return s.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  @override
  void serializeAttribute(String key, Map<String, dynamic> into) {
    switch (key) {
      case _kName:
        if (name != null) into[_kName] = name;
      case _kBuildSettings:
        // Apply normalization to a COPY — never mutate in-memory buildSettings.
        final normalized = Map<String, dynamic>.of(buildSettings);
        _normalizeArraySettings(normalized);
        into[_kBuildSettings] =
            normalized; // ALWAYS emit case _kBaseConfigurationReference:
        if (_baseConfigurationReference != null) {
          into[_kBaseConfigurationReference] =
              _baseConfigurationReference!.uuid;
        }
      case _kBaseConfigurationReferenceAnchor:
        if (_baseConfigurationReferenceAnchor != null) {
          into[_kBaseConfigurationReferenceAnchor] =
              _baseConfigurationReferenceAnchor!.uuid;
        }
      case _kBaseConfigurationReferenceRelativePath:
        if (baseConfigurationReferenceRelativePath != null) {
          into[_kBaseConfigurationReferenceRelativePath] =
              baseConfigurationReferenceRelativePath;
        }
    }
  }

  @override
  void serializeAttributeAsTree(
    String key,
    Map<String, dynamic> into,
    Set<String> visited,
  ) {
    switch (key) {
      case _kBuildSettings:
        // No normalization for tree output — tree is diagnostic.
        into[_kBuildSettings] = Map<String, dynamic>.of(buildSettings);
      case _kName:
        serializeAttribute(key, into);
      case _kBaseConfigurationReferenceRelativePath:
        serializeAttribute(key, into);
      case _kBaseConfigurationReference:
        if (_baseConfigurationReference != null) {
          final ref = _baseConfigurationReference!;
          if (visited.contains(ref.uuid)) {
            into[_kBaseConfigurationReference] = '<cycle: ${ref.uuid}>';
          } else {
            into[_kBaseConfigurationReference] = ref.toTreeHash(visited);
          }
        }
      case _kBaseConfigurationReferenceAnchor:
        if (_baseConfigurationReferenceAnchor != null) {
          final ref = _baseConfigurationReferenceAnchor!;
          if (visited.contains(ref.uuid)) {
            into[_kBaseConfigurationReferenceAnchor] = '<cycle: ${ref.uuid}>';
          } else {
            into[_kBaseConfigurationReferenceAnchor] = ref.toTreeHash(visited);
          }
        }
    }
  }

  // ---------------------------------------------------------------------------
  // Deserialization
  // ---------------------------------------------------------------------------

  @override
  void readAttribute(
    String key,
    dynamic value,
    Map<String, dynamic> objectsByUuidPlist,
  ) {
    switch (key) {
      case _kName:
        name = value is String ? value : null;
      case _kBuildSettings:
        // Store plist value as-is — normalization is write-time only.
        if (value is Map) {
          buildSettings = {};
          value.forEach((k, v) => buildSettings[k.toString()] = v);
        }
      case _kBaseConfigurationReference:
        if (value is String) {
          final resolved = objectWithUuid(value, objectsByUuidPlist);
          baseConfigurationReference = resolved is PBXFileReference
              ? resolved
              : null;
        }
      case _kBaseConfigurationReferenceAnchor:
        if (value is String) {
          final resolved = objectWithUuid(value, objectsByUuidPlist);
          baseConfigurationReferenceAnchor = resolved;
        }
      case _kBaseConfigurationReferenceRelativePath:
        baseConfigurationReferenceRelativePath = value is String ? value : null;
    }
  }

  // ---------------------------------------------------------------------------
  // Reference counting lifecycle
  // ---------------------------------------------------------------------------

  @override
  void removeReference(AbstractObject obj) {
    if (identical(_baseConfigurationReference, obj)) {
      _baseConfigurationReference!.removeReferrer(this);
      _baseConfigurationReference = null;
    }
    if (identical(_baseConfigurationReferenceAnchor, obj)) {
      _baseConfigurationReferenceAnchor!.removeReferrer(this);
      _baseConfigurationReferenceAnchor = null;
    }
  }

  @override
  void clearRelationships() {
    _baseConfigurationReference?.removeReferrer(this);
    _baseConfigurationReference = null;
    _baseConfigurationReferenceAnchor?.removeReferrer(this);
    _baseConfigurationReferenceAnchor = null;
  }

  // ---------------------------------------------------------------------------
  // resolveBuildSetting engine
  // ---------------------------------------------------------------------------

  /// Extract the captured variable name from a [_captureVariable] match.
  /// Group 1 = `${VAR}`, group 2 = `$(VAR)`.
  String? _extractVarName(RegExpMatch m) => m.group(1) ?? m.group(2);

  /// Recursively resolve `${VAR}`/`$(VAR)` references in [value].
  /// Port of: resolve_variable_substitution.
  /// - null → null
  /// - List → map each element through this method
  /// - String → replace each `${VAR}`/`$(VAR)` with resolved value
  /// - cycle guard: if varName is in [activeKeys] → return [_kMutualRecursionSentinel]
  dynamic _resolveVariableSubstitution(
    String key,
    dynamic value,
    Set<String> activeKeys,
  ) {
    if (value == null) return null;
    if (value is List) {
      return value
          .map((e) => _resolveVariableSubstitution(key, e, activeKeys))
          .toList();
    }
    if (value is String) {
      final matches = _captureVariable.allMatches(value).toList();
      if (matches.isEmpty) return value;

      // Replace each variable reference with its resolved value.
      String result = value;
      for (final match in matches) {
        final varName = _extractVarName(match);
        if (varName == null) continue;
        // Mutual recursion guard: if we're already resolving this variable, return sentinel.
        if (activeKeys.contains(varName)) return _kMutualRecursionSentinel;
        final resolved = resolveBuildSetting(varName, Set.of(activeKeys));
        final replacement = (resolved is String ? resolved : null) ?? '';
        result = result.replaceFirst(match.group(0)!, replacement);
      }
      return result;
    }
    return value;
  }

  /// Expand [buildSettingValue] by replacing `$(inherited)`/`${inherited}` with [configValue].
  /// Port of: expand_build_setting.
  /// Handles cross-type:
  /// - buildSettingValue is List + configValue is String → split configValue
  /// - buildSettingValue is String + configValue is List → split buildSettingValue
  dynamic _expandBuildSetting(dynamic buildSettingValue, dynamic configValue) {
    // Cross-type coercion to match Ruby behavior.
    if (buildSettingValue is List && configValue is String) {
      configValue = _splitBuildSettingString(configValue);
    }
    if (buildSettingValue is String && configValue is List) {
      buildSettingValue = _splitBuildSettingString(buildSettingValue);
    }

    final inherited =
        configValue ?? (buildSettingValue is String ? '' : <String>[]);

    if (buildSettingValue is String) {
      var result = buildSettingValue;
      for (final keyword in MiscConstants.inheritedKeywords) {
        final replacement = inherited is List
            ? inherited.join(' ')
            : inherited.toString();
        result = result.replaceAll(keyword, replacement);
      }
      return result;
    }

    if (buildSettingValue is List) {
      final expanded = <dynamic>[];
      for (final item in buildSettingValue) {
        if (item is String && MiscConstants.inheritedKeywords.contains(item)) {
          if (inherited is List) {
            expanded.addAll(inherited);
          } else {
            expanded.add(inherited);
          }
        } else {
          expanded.add(item);
        }
      }
      return expanded;
    }

    return buildSettingValue;
  }

  /// Resolve the effective value of a build setting [key].
  /// Port of: resolve_build_setting.
  /// Precedence (lowest to highest):
  /// 1. Built-in defaults (CONFIGURATION → name)
  /// 2. Project-level build configuration
  /// 3. xcconfig settings (via [setLoadedXcConfig] — wired later)
  /// 4. In-map buildSettings value (this object's settings)
  /// Each level is folded via [_expandBuildSetting] which handles `$(inherited)`.
  /// Returns null if the key is absent and no defaults apply.
  /// Returns null if mutual-recursion sentinel is detected.
  dynamic resolveBuildSetting(String key, [Set<String>? activeKeys]) {
    final visiting = {...(activeKeys ?? <String>{}), key};
    final rawValue = buildSettings[key];
    final setting = _resolveVariableSubstitution(key, rawValue, visiting);

    // xcconfig branch — (integration)
    // If baseConfigurationReference points at an .xcconfig file that has been
    // pre-loaded via setXcConfig(), use its attributes as a resolution layer.
    final Map<String, dynamic> configSettings =
        _loadedXcConfigSettings ?? const <String, dynamic>{};

    // project-level lookup — stub for ([XcodeProject] wires project.buildConfigurationList)
    String? projectSetting; // null stub

    final defaults = <String, String>{'CONFIGURATION': name ?? ''};

    // Combine: defaults < projectSetting < configSettings[key] < in-map setting
    final candidates = <dynamic>[
      defaults[key],
      projectSetting,
      configSettings[key],
      setting,
    ].where((c) => c != null).toList();

    if (candidates.isEmpty) return null;

    final result = candidates.cast<dynamic>().reduce(
      (inherited, value) => _expandBuildSetting(value, inherited),
    );

    // Post-process: sentinel → null; preserve String and List types (1:1 Ruby contract).
    if (result == _kMutualRecursionSentinel) return null;
    if (result is String || result is List) return result;
    return null;
  }
}
