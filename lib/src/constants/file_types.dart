// Port of Xcodeproj::Constants FILE_TYPES_BY_EXTENSION
// static const Map, not enums — maps file extension (without dot) to UTI string
// All 35 entries ported verbatim from Ruby source
class FileTypes {
  FileTypes._();

  /// The known file types corresponding to each extension.
  /// Ruby: FILE_TYPES_BY_EXTENSION (35 entries)
  /// Keys: file extension without leading dot
  /// Values: UTI string
  static const Map<String, String> byExtension = {
    'a': 'archive.ar',
    'apns': 'text',
    'app': 'wrapper.application',
    'appex': 'wrapper.app-extension',
    'bundle': 'wrapper.plug-in',
    'cpp': 'sourcecode.cpp.cpp',
    'dylib': 'compiled.mach-o.dylib',
    'entitlements': 'text.plist.entitlements',
    'framework': 'wrapper.framework',
    'gif': 'image.gif',
    'gpx': 'text.xml',
    'h': 'sourcecode.c.h',
    'hpp': 'sourcecode.cpp.h',
    'm': 'sourcecode.c.objc',
    'markdown': 'text',
    'mdimporter': 'wrapper.cfbundle',
    'modulemap': 'sourcecode.module',
    'mov': 'video.quicktime',
    'mp3': 'audio.mp3',
    'octest': 'wrapper.cfbundle',
    'pch': 'sourcecode.c.h',
    'plist': 'text.plist.xml',
    'png': 'image.png',
    'sh': 'text.script.sh',
    'sks': 'file.sks',
    'storyboard': 'file.storyboard',
    'strings': 'text.plist.strings',
    'swift': 'sourcecode.swift',
    'xcassets': 'folder.assetcatalog',
    'xcconfig': 'text.xcconfig',
    'xcdatamodel': 'wrapper.xcdatamodel',
    'xcodeproj': 'wrapper.pb-project',
    'xctest': 'wrapper.cfbundle',
    'xib': 'file.xib',
    'zip': 'archive.zip',
  };
}
