// static const Map, not enums
// Dart keys: String composite keys with comma separators ('debug,ios' or 'all')
// Single-element keys omit the comma: 'ios', 'debug', 'release', etc.
class BuildSettings {
  BuildSettings._();

  // COMMON_BUILD_SETTINGS
  // Dart: keyed by 'all', 'debug', 'release', 'ios', 'osx', etc.
  static const Map<String, Map<String, Object>> commonBuildSettings = {
    'all': {},

    'debug': {},

    'release': {},

    'ios': {'SDKROOT': 'iphoneos'},

    'osx': {'SDKROOT': 'macosx'},

    'tvos': {'SDKROOT': 'appletvos'},

    'visionos': {'SDKROOT': 'xros'},

    'watchos': {'SDKROOT': 'watchos'},

    'debug,osx': {},

    'release,osx': {},

    'debug,ios': {},

    'release,ios': {'VALIDATE_PRODUCT': 'YES'},

    'debug,tvos': {},

    'release,tvos': {'VALIDATE_PRODUCT': 'YES'},

    'debug,watchos': {},

    'release,watchos': {'VALIDATE_PRODUCT': 'YES'},

    'swift': {},

    'debug,application,swift': {},

    'debug,swift': {},

    'release,swift': {},

    'debug,static_library,swift': {},

    'framework': {
      'CURRENT_PROJECT_VERSION': '1',
      'DEFINES_MODULE': 'YES',
      'DYLIB_COMPATIBILITY_VERSION': '1',
      'DYLIB_CURRENT_VERSION': '1',
      'DYLIB_INSTALL_NAME_BASE': '@rpath',
      'INSTALL_PATH': r'$(LOCAL_LIBRARY_DIR)/Frameworks',
      'PRODUCT_NAME': r'$(TARGET_NAME:c99extidentifier)',
      'SKIP_INSTALL': 'YES',
      'VERSION_INFO_PREFIX': '',
      'VERSIONING_SYSTEM': 'apple-generic',
    },

    'ios,framework': {
      'LD_RUNPATH_SEARCH_PATHS':
          r'$(inherited) @executable_path/Frameworks @loader_path/Frameworks',
      'TARGETED_DEVICE_FAMILY': '1,2',
    },

    'osx,framework': {
      'COMBINE_HIDPI_IMAGES': 'YES',
      'LD_RUNPATH_SEARCH_PATHS':
          r'$(inherited) @executable_path/../Frameworks @loader_path/Frameworks',
    },

    'watchos,framework': {
      'APPLICATION_EXTENSION_API_ONLY': 'YES',
      'LD_RUNPATH_SEARCH_PATHS':
          r'$(inherited) @executable_path/Frameworks @loader_path/Frameworks',
      'TARGETED_DEVICE_FAMILY': '4',
    },

    'tvos,framework': {
      'LD_RUNPATH_SEARCH_PATHS':
          r'$(inherited) @executable_path/Frameworks @loader_path/Frameworks',
      'TARGETED_DEVICE_FAMILY': '3',
    },

    'framework,swift': {'DEFINES_MODULE': 'YES'},

    'osx,static_library': {'EXECUTABLE_PREFIX': 'lib', 'SKIP_INSTALL': 'YES'},

    'ios,static_library': {
      'OTHER_LDFLAGS': '-ObjC',
      'SKIP_INSTALL': 'YES',
      'TARGETED_DEVICE_FAMILY': '1,2',
    },

    'watchos,static_library': {
      'OTHER_LDFLAGS': '-ObjC',
      'SKIP_INSTALL': 'YES',
      'TARGETED_DEVICE_FAMILY': '4',
    },

    'tvos,static_library': {
      'OTHER_LDFLAGS': '-ObjC',
      'SKIP_INSTALL': 'YES',
      'TARGETED_DEVICE_FAMILY': '3',
    },

    'osx,dynamic_library': {
      'DYLIB_COMPATIBILITY_VERSION': '1',
      'DYLIB_CURRENT_VERSION': '1',
      'EXECUTABLE_PREFIX': 'lib',
      'SKIP_INSTALL': 'YES',
    },

    'application': {
      'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
      'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME': 'AccentColor',
    },

    'ios,application': {
      'LD_RUNPATH_SEARCH_PATHS': r'$(inherited) @executable_path/Frameworks',
      'TARGETED_DEVICE_FAMILY': '1,2',
    },

    'osx,application': {
      'COMBINE_HIDPI_IMAGES': 'YES',
      'LD_RUNPATH_SEARCH_PATHS': r'$(inherited) @executable_path/../Frameworks',
    },

    'watchos,application': {
      'SKIP_INSTALL': 'YES',
      'TARGETED_DEVICE_FAMILY': '4',
    },

    'tvos,application': {
      'ASSETCATALOG_COMPILER_APPICON_NAME': 'App Icon & Top Shelf Image',
      'LD_RUNPATH_SEARCH_PATHS': r'$(inherited) @executable_path/Frameworks',
      'TARGETED_DEVICE_FAMILY': '3',
    },

    'tvos,application,swift': {'ENABLE_PREVIEWS': 'YES'},

    'watchos,application,swift': {
      'ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES': 'YES',
    },

    'bundle': {'WRAPPER_EXTENSION': 'bundle', 'SKIP_INSTALL': 'YES'},

    'ios,bundle': {'SDKROOT': 'iphoneos'},

    'osx,bundle': {
      'COMBINE_HIDPI_IMAGES': 'YES',
      'INSTALL_PATH': r'$(LOCAL_LIBRARY_DIR)/Bundles',
      'SDKROOT': 'macosx',
    },
  };

  // PROJECT_DEFAULT_BUILD_SETTINGS
  // Dart: keyed by 'all', 'release', 'debug'
  static const Map<String, Map<String, Object>> projectDefaultBuildSettings = {
    'all': {
      'ALWAYS_SEARCH_USER_PATHS': 'NO',
      'CLANG_ANALYZER_NONNULL': 'YES',
      'CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION': 'YES_AGGRESSIVE',
      'CLANG_CXX_LANGUAGE_STANDARD': 'gnu++14',
      'CLANG_CXX_LIBRARY': 'libc++',
      'CLANG_ENABLE_MODULES': 'YES',
      'CLANG_ENABLE_OBJC_ARC': 'YES',
      'CLANG_ENABLE_OBJC_WEAK': 'YES',
      'CLANG_WARN__DUPLICATE_METHOD_MATCH': 'YES',
      'CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING': 'YES',
      'CLANG_WARN_BOOL_CONVERSION': 'YES',
      'CLANG_WARN_COMMA': 'YES',
      'CLANG_WARN_CONSTANT_CONVERSION': 'YES',
      'CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS': 'YES',
      'CLANG_WARN_DIRECT_OBJC_ISA_USAGE': 'YES_ERROR',
      'CLANG_WARN_DOCUMENTATION_COMMENTS': 'YES',
      'CLANG_WARN_EMPTY_BODY': 'YES',
      'CLANG_WARN_ENUM_CONVERSION': 'YES',
      'CLANG_WARN_INFINITE_RECURSION': 'YES',
      'CLANG_WARN_INT_CONVERSION': 'YES',
      'CLANG_WARN_NON_LITERAL_NULL_CONVERSION': 'YES',
      'CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF': 'YES',
      'CLANG_WARN_OBJC_LITERAL_CONVERSION': 'YES',
      'CLANG_WARN_OBJC_ROOT_CLASS': 'YES_ERROR',
      'CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER': 'YES',
      'CLANG_WARN_RANGE_LOOP_ANALYSIS': 'YES',
      'CLANG_WARN_STRICT_PROTOTYPES': 'YES',
      'CLANG_WARN_SUSPICIOUS_MOVE': 'YES',
      'CLANG_WARN_UNGUARDED_AVAILABILITY': 'YES_AGGRESSIVE',
      'CLANG_WARN_UNREACHABLE_CODE': 'YES',
      'COPY_PHASE_STRIP': 'NO',
      'ENABLE_STRICT_OBJC_MSGSEND': 'YES',
      'GCC_C_LANGUAGE_STANDARD': 'gnu11',
      'GCC_NO_COMMON_BLOCKS': 'YES',
      'GCC_WARN_64_TO_32_BIT_CONVERSION': 'YES',
      'GCC_WARN_ABOUT_RETURN_TYPE': 'YES_ERROR',
      'GCC_WARN_UNDECLARED_SELECTOR': 'YES',
      'GCC_WARN_UNINITIALIZED_AUTOS': 'YES_AGGRESSIVE',
      'GCC_WARN_UNUSED_FUNCTION': 'YES',
      'GCC_WARN_UNUSED_VARIABLE': 'YES',
      'MTL_FAST_MATH': 'YES',
      'PRODUCT_NAME': r'$(TARGET_NAME)',
      'SWIFT_VERSION': '5.0',
    },

    'release': {
      'DEBUG_INFORMATION_FORMAT': 'dwarf-with-dsym',
      'ENABLE_NS_ASSERTIONS': 'NO',
      'MTL_ENABLE_DEBUG_INFO': 'NO',
      'SWIFT_COMPILATION_MODE': 'wholemodule',
      'SWIFT_OPTIMIZATION_LEVEL': '-O',
    },

    'debug': {
      'DEBUG_INFORMATION_FORMAT': 'dwarf',
      'ENABLE_TESTABILITY': 'YES',
      'GCC_DYNAMIC_NO_PIC': 'NO',
      'GCC_OPTIMIZATION_LEVEL': '0',
      'GCC_PREPROCESSOR_DEFINITIONS': <String>['DEBUG=1', r'$(inherited)'],
      'MTL_ENABLE_DEBUG_INFO': 'INCLUDE_SOURCE',
      'ONLY_ACTIVE_ARCH': 'YES',
      'SWIFT_ACTIVE_COMPILATION_CONDITIONS': 'DEBUG',
      'SWIFT_OPTIMIZATION_LEVEL': '-Onone',
    },
  };
}
