// Port of Xcodeproj::Constants object/archive version constants
// static const int/String/Map, not enums
class ObjectVersions {
  ObjectVersions._();

  /// The last known archive version to Xcodeproj.
  /// Ruby: LAST_KNOWN_ARCHIVE_VERSION = 1
  static const int lastKnownArchiveVersion = 1;

  /// The default object version for Xcodeproj.
  /// Ruby: DEFAULT_OBJECT_VERSION = 46
  static const int defaultObjectVersion = 46;

  /// The last known object version to Xcodeproj.
  /// Ruby: LAST_KNOWN_OBJECT_VERSION = 77
  static const int lastKnownObjectVersion = 77;

  /// The last known Xcode version to Xcodeproj.
  /// Ruby: LAST_UPGRADE_CHECK = '1600'
  static const String lastUpgradeCheck = '1600';

  /// The last known Xcode Swift version to Xcodeproj.
  /// Ruby: LAST_SWIFT_UPGRADE_CHECK = '1600'
  static const String lastSwiftUpgradeCheck = '1600';

  /// The compatibility version string for different object versions.
  /// Ruby: COMPATIBILITY_VERSION_BY_OBJECT_VERSION
  static const Map<int, String> compatibilityVersionByObjectVersion = {
    77: 'Xcode 16.0', // with project compatibility set to Xcode 16.0
    71: 'Xcode 16.2',
    70: 'Xcode 16.0',
    63: 'Xcode 15.3',
    60: 'Xcode 15.0',
    56: 'Xcode 14.0',
    55: 'Xcode 13.0',
    54: 'Xcode 12.0',
    53: 'Xcode 11.4',
    52: 'Xcode 11.0',
    51: 'Xcode 10.0',
    50: 'Xcode 9.3',
    48: 'Xcode 8.0',
    47: 'Xcode 6.3',
    46: 'Xcode 3.2',
    45: 'Xcode 3.1',
  };
}
