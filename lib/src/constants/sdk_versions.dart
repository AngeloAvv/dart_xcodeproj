// Port of Xcodeproj::Constants SDK/version constants
// static const String, not enums — matches Ruby string approach
class SdkVersions {
  SdkVersions._();

  /// The last known iOS SDK (stable).
  /// Ruby: LAST_KNOWN_IOS_SDK = '18.0'
  static const String lastKnownIosSdk = '18.0';

  /// The last known OS X SDK (stable).
  /// Ruby: LAST_KNOWN_OSX_SDK = '15.0'
  static const String lastKnownOsxSdk = '15.0';

  /// The last known tvOS SDK (stable).
  /// Ruby: LAST_KNOWN_TVOS_SDK = '18.0'
  static const String lastKnownTvosSdk = '18.0';

  /// The last known visionOS SDK (unstable).
  /// Ruby: LAST_KNOWN_VISIONOS_SDK = '2.0'
  static const String lastKnownVisionosSdk = '2.0';

  /// The last known watchOS SDK (stable).
  /// Ruby: LAST_KNOWN_WATCHOS_SDK = '11.0'
  static const String lastKnownWatchosSdk = '11.0';

  /// The last known Swift version (stable).
  /// Ruby: LAST_KNOWN_SWIFT_VERSION = '5.0'
  static const String lastKnownSwiftVersion = '5.0';

  /// The version of .xcscheme files supported by Xcodeproj.
  /// Ruby: XCSCHEME_FORMAT_VERSION = '1.3'
  static const String xcschemeFormatVersion = '1.3';
}
