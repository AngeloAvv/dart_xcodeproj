import 'package:test/test.dart';
import 'package:dart_xcodeproj/src/constants/sdk_versions.dart';
import 'package:dart_xcodeproj/src/constants/object_versions.dart';
import 'package:dart_xcodeproj/src/constants/file_types.dart';
import 'package:dart_xcodeproj/src/constants/product_types.dart';
import 'package:dart_xcodeproj/src/constants/build_settings.dart';
import 'package:dart_xcodeproj/src/constants/misc.dart';

void main() {
  group('SdkVersions', () {
    test('lastKnownIosSdk = 18.0', () {
      expect(SdkVersions.lastKnownIosSdk, equals('18.0'));
    });
    test('lastKnownOsxSdk = 15.0', () {
      expect(SdkVersions.lastKnownOsxSdk, equals('15.0'));
    });
    test('lastKnownTvosSdk = 18.0', () {
      expect(SdkVersions.lastKnownTvosSdk, equals('18.0'));
    });
    test('lastKnownVisionosSdk = 2.0', () {
      expect(SdkVersions.lastKnownVisionosSdk, equals('2.0'));
    });
    test('lastKnownWatchosSdk = 11.0', () {
      expect(SdkVersions.lastKnownWatchosSdk, equals('11.0'));
    });
    test('lastKnownSwiftVersion = 5.0', () {
      expect(SdkVersions.lastKnownSwiftVersion, equals('5.0'));
    });
    test('xcschemeFormatVersion = 1.3', () {
      expect(SdkVersions.xcschemeFormatVersion, equals('1.3'));
    });
    test('all SDK version fields non-empty', () {
      expect(SdkVersions.lastKnownOsxSdk, isNotEmpty);
      expect(SdkVersions.lastKnownTvosSdk, isNotEmpty);
      expect(SdkVersions.lastKnownVisionosSdk, isNotEmpty);
      expect(SdkVersions.lastKnownWatchosSdk, isNotEmpty);
      expect(SdkVersions.lastKnownSwiftVersion, isNotEmpty);
      expect(SdkVersions.xcschemeFormatVersion, isNotEmpty);
    });
  });

  group('ObjectVersions', () {
    test('lastKnownArchiveVersion = 1', () {
      expect(ObjectVersions.lastKnownArchiveVersion, equals(1));
    });
    test('defaultObjectVersion = 46', () {
      expect(ObjectVersions.defaultObjectVersion, equals(46));
    });
    test('lastKnownObjectVersion = 77', () {
      expect(ObjectVersions.lastKnownObjectVersion, equals(77));
    });
    test('lastUpgradeCheck = 1600', () {
      expect(ObjectVersions.lastUpgradeCheck, equals('1600'));
    });
    test('lastSwiftUpgradeCheck = 1600', () {
      expect(ObjectVersions.lastSwiftUpgradeCheck, equals('1600'));
    });
    test('compatibilityVersionByObjectVersion[77] = "Xcode 16.0"', () {
      expect(
        ObjectVersions.compatibilityVersionByObjectVersion[77],
        equals('Xcode 16.0'),
      );
    });
    test('compatibilityVersionByObjectVersion[46] = "Xcode 3.2"', () {
      expect(
        ObjectVersions.compatibilityVersionByObjectVersion[46],
        equals('Xcode 3.2'),
      );
    });
    test('compatibilityVersionByObjectVersion[45] = "Xcode 3.1"', () {
      expect(
        ObjectVersions.compatibilityVersionByObjectVersion[45],
        equals('Xcode 3.1'),
      );
    });
    test('compatibilityVersionByObjectVersion non-empty with 16 entries', () {
      expect(ObjectVersions.compatibilityVersionByObjectVersion, isNotEmpty);
      expect(
        ObjectVersions.compatibilityVersionByObjectVersion.length,
        equals(16),
      );
    });
  });

  group('FileTypes', () {
    test('byExtension non-empty with 35 entries', () {
      expect(FileTypes.byExtension, isNotEmpty);
      expect(FileTypes.byExtension.length, equals(35));
    });
    test('swift → sourcecode.swift', () {
      expect(FileTypes.byExtension['swift'], equals('sourcecode.swift'));
    });
    test('h → sourcecode.c.h', () {
      expect(FileTypes.byExtension['h'], equals('sourcecode.c.h'));
    });
    test('m → sourcecode.c.objc', () {
      expect(FileTypes.byExtension['m'], equals('sourcecode.c.objc'));
    });
    test('cpp → sourcecode.cpp.cpp', () {
      expect(FileTypes.byExtension['cpp'], equals('sourcecode.cpp.cpp'));
    });
    test('hpp → sourcecode.cpp.h', () {
      expect(FileTypes.byExtension['hpp'], equals('sourcecode.cpp.h'));
    });
    test('framework → wrapper.framework', () {
      expect(FileTypes.byExtension['framework'], equals('wrapper.framework'));
    });
    test('app → wrapper.application', () {
      expect(FileTypes.byExtension['app'], equals('wrapper.application'));
    });
    test('plist → text.plist.xml', () {
      expect(FileTypes.byExtension['plist'], equals('text.plist.xml'));
    });
    test('xcconfig → text.xcconfig', () {
      expect(FileTypes.byExtension['xcconfig'], equals('text.xcconfig'));
    });
    test('storyboard → file.storyboard', () {
      expect(FileTypes.byExtension['storyboard'], equals('file.storyboard'));
    });
    test('xib → file.xib', () {
      expect(FileTypes.byExtension['xib'], equals('file.xib'));
    });
    test('png → image.png', () {
      expect(FileTypes.byExtension['png'], equals('image.png'));
    });
    test('xcassets → folder.assetcatalog', () {
      expect(FileTypes.byExtension['xcassets'], equals('folder.assetcatalog'));
    });
    test('a → archive.ar', () {
      expect(FileTypes.byExtension['a'], equals('archive.ar'));
    });
    test('dylib → compiled.mach-o.dylib', () {
      expect(FileTypes.byExtension['dylib'], equals('compiled.mach-o.dylib'));
    });
  });

  group('ProductTypes', () {
    test('productTypeUti non-empty with 21 entries', () {
      expect(ProductTypes.productTypeUti, isNotEmpty);
      expect(ProductTypes.productTypeUti.length, equals(21));
    });
    test('application UTI', () {
      expect(
        ProductTypes.productTypeUti['application'],
        equals('com.apple.product-type.application'),
      );
    });
    test('framework UTI', () {
      expect(
        ProductTypes.productTypeUti['framework'],
        equals('com.apple.product-type.framework'),
      );
    });
    test('unit_test_bundle UTI', () {
      expect(
        ProductTypes.productTypeUti['unit_test_bundle'],
        equals('com.apple.product-type.bundle.unit-test'),
      );
    });
    test('ui_test_bundle UTI', () {
      expect(
        ProductTypes.productTypeUti['ui_test_bundle'],
        equals('com.apple.product-type.bundle.ui-testing'),
      );
    });
    test('static_library UTI', () {
      expect(
        ProductTypes.productTypeUti['static_library'],
        equals('com.apple.product-type.library.static'),
      );
    });
    test('xpc_service UTI', () {
      expect(
        ProductTypes.productTypeUti['xpc_service'],
        equals('com.apple.product-type.xpc-service'),
      );
    });
    test('productUtiExtensions non-empty with 16 entries', () {
      expect(ProductTypes.productUtiExtensions, isNotEmpty);
      expect(ProductTypes.productUtiExtensions.length, equals(16));
    });
    test('application extension = app', () {
      expect(ProductTypes.productUtiExtensions['application'], equals('app'));
    });
    test('framework extension = framework', () {
      expect(
        ProductTypes.productUtiExtensions['framework'],
        equals('framework'),
      );
    });
    test('unit_test_bundle extension = xctest', () {
      expect(
        ProductTypes.productUtiExtensions['unit_test_bundle'],
        equals('xctest'),
      );
    });
  });

  group('BuildSettings', () {
    test('commonBuildSettings has ios SDKROOT = iphoneos', () {
      expect(
        BuildSettings.commonBuildSettings['ios']?['SDKROOT'],
        equals('iphoneos'),
      );
    });
    test('commonBuildSettings has osx SDKROOT = macosx', () {
      expect(
        BuildSettings.commonBuildSettings['osx']?['SDKROOT'],
        equals('macosx'),
      );
    });
    test('commonBuildSettings has tvos SDKROOT = appletvos', () {
      expect(
        BuildSettings.commonBuildSettings['tvos']?['SDKROOT'],
        equals('appletvos'),
      );
    });
    test('commonBuildSettings has release,ios VALIDATE_PRODUCT = YES', () {
      expect(
        BuildSettings.commonBuildSettings['release,ios']?['VALIDATE_PRODUCT'],
        equals('YES'),
      );
    });
    test('commonBuildSettings has release,tvos VALIDATE_PRODUCT = YES', () {
      expect(
        BuildSettings.commonBuildSettings['release,tvos']?['VALIDATE_PRODUCT'],
        equals('YES'),
      );
    });
    test('commonBuildSettings has framework DEFINES_MODULE = YES', () {
      expect(
        BuildSettings.commonBuildSettings['framework']?['DEFINES_MODULE'],
        equals('YES'),
      );
    });
    test(
      'projectDefaultBuildSettings.all has ALWAYS_SEARCH_USER_PATHS = NO',
      () {
        expect(
          BuildSettings
              .projectDefaultBuildSettings['all']?['ALWAYS_SEARCH_USER_PATHS'],
          equals('NO'),
        );
      },
    );
    test(
      'projectDefaultBuildSettings.all has CLANG_ANALYZER_NONNULL = YES',
      () {
        expect(
          BuildSettings
              .projectDefaultBuildSettings['all']?['CLANG_ANALYZER_NONNULL'],
          equals('YES'),
        );
      },
    );
    test(
      'projectDefaultBuildSettings.debug has DEBUG_INFORMATION_FORMAT = dwarf',
      () {
        expect(
          BuildSettings
              .projectDefaultBuildSettings['debug']?['DEBUG_INFORMATION_FORMAT'],
          equals('dwarf'),
        );
      },
    );
    test('projectDefaultBuildSettings.debug has ENABLE_TESTABILITY = YES', () {
      expect(
        BuildSettings
            .projectDefaultBuildSettings['debug']?['ENABLE_TESTABILITY'],
        equals('YES'),
      );
    });
    test(
      'projectDefaultBuildSettings.debug has GCC_OPTIMIZATION_LEVEL = 0',
      () {
        expect(
          BuildSettings
              .projectDefaultBuildSettings['debug']?['GCC_OPTIMIZATION_LEVEL'],
          equals('0'),
        );
      },
    );
    test('projectDefaultBuildSettings.debug has ONLY_ACTIVE_ARCH = YES', () {
      expect(
        BuildSettings.projectDefaultBuildSettings['debug']?['ONLY_ACTIVE_ARCH'],
        equals('YES'),
      );
    });
    test(
      'projectDefaultBuildSettings.debug has SWIFT_OPTIMIZATION_LEVEL = -Onone',
      () {
        expect(
          BuildSettings
              .projectDefaultBuildSettings['debug']?['SWIFT_OPTIMIZATION_LEVEL'],
          equals('-Onone'),
        );
      },
    );
    test(
      'projectDefaultBuildSettings.debug has GCC_PREPROCESSOR_DEFINITIONS list',
      () {
        final defs = BuildSettings
            .projectDefaultBuildSettings['debug']?['GCC_PREPROCESSOR_DEFINITIONS'];
        expect(defs, isA<List<dynamic>>());
        expect(defs as List, contains('DEBUG=1'));
        expect(defs, contains(r'$(inherited)'));
      },
    );
    test(
      'projectDefaultBuildSettings.release has DEBUG_INFORMATION_FORMAT = dwarf-with-dsym',
      () {
        expect(
          BuildSettings
              .projectDefaultBuildSettings['release']?['DEBUG_INFORMATION_FORMAT'],
          equals('dwarf-with-dsym'),
        );
      },
    );
    test(
      'projectDefaultBuildSettings.release has ENABLE_NS_ASSERTIONS = NO',
      () {
        expect(
          BuildSettings
              .projectDefaultBuildSettings['release']?['ENABLE_NS_ASSERTIONS'],
          equals('NO'),
        );
      },
    );
    test(
      'projectDefaultBuildSettings.release has SWIFT_COMPILATION_MODE = wholemodule',
      () {
        expect(
          BuildSettings
              .projectDefaultBuildSettings['release']?['SWIFT_COMPILATION_MODE'],
          equals('wholemodule'),
        );
      },
    );
    test(
      'projectDefaultBuildSettings.release has SWIFT_OPTIMIZATION_LEVEL = -O',
      () {
        expect(
          BuildSettings
              .projectDefaultBuildSettings['release']?['SWIFT_OPTIMIZATION_LEVEL'],
          equals('-O'),
        );
      },
    );
  });

  group('MiscConstants', () {
    test('knownIsas has all four hierarchy keys', () {
      expect(
        MiscConstants.knownIsas.keys,
        containsAll([
          'AbstractObject',
          'AbstractBuildPhase',
          'AbstractTarget',
          'PBXGroup',
        ]),
      );
    });
    test('knownIsas.AbstractObject has PBXFileReference', () {
      expect(
        MiscConstants.knownIsas['AbstractObject'],
        contains('PBXFileReference'),
      );
    });
    test('knownIsas.AbstractObject has PBXProject', () {
      expect(MiscConstants.knownIsas['AbstractObject'], contains('PBXProject'));
    });
    test('knownIsas.AbstractBuildPhase has PBXSourcesBuildPhase', () {
      expect(
        MiscConstants.knownIsas['AbstractBuildPhase'],
        contains('PBXSourcesBuildPhase'),
      );
    });
    test('knownIsas.AbstractTarget includes PBXNativeTarget', () {
      expect(
        MiscConstants.knownIsas['AbstractTarget'],
        contains('PBXNativeTarget'),
      );
    });
    test('knownIsas.AbstractTarget includes PBXAggregateTarget', () {
      expect(
        MiscConstants.knownIsas['AbstractTarget'],
        contains('PBXAggregateTarget'),
      );
    });
    test('knownIsas.PBXGroup contains XCVersionGroup', () {
      expect(MiscConstants.knownIsas['PBXGroup'], contains('XCVersionGroup'));
    });
    test('copyFilesBuildPhaseDestinations.frameworks = "10"', () {
      expect(
        MiscConstants.copyFilesBuildPhaseDestinations['frameworks'],
        equals('10'),
      );
    });
    test('copyFilesBuildPhaseDestinations.resources = "7"', () {
      expect(
        MiscConstants.copyFilesBuildPhaseDestinations['resources'],
        equals('7'),
      );
    });
    test('copyFilesBuildPhaseDestinations.absolute_path = "0"', () {
      expect(
        MiscConstants.copyFilesBuildPhaseDestinations['absolute_path'],
        equals('0'),
      );
    });
    test('proxyTypes.native_target = "1"', () {
      expect(MiscConstants.proxyTypes['native_target'], equals('1'));
    });
    test('proxyTypes.reference = "2"', () {
      expect(MiscConstants.proxyTypes['reference'], equals('2'));
    });
    test('headerFilesExtensions contains .h and .hpp', () {
      expect(MiscConstants.headerFilesExtensions, containsAll(['.h', '.hpp']));
    });
    test('headerFilesExtensions has 9 entries', () {
      expect(MiscConstants.headerFilesExtensions.length, equals(9));
    });
    test('inheritedKeywords contains \$(inherited)', () {
      expect(MiscConstants.inheritedKeywords, contains(r'$(inherited)'));
    });
    test('inheritedKeywords contains \${inherited}', () {
      expect(MiscConstants.inheritedKeywords, contains(r'${inherited}'));
    });
    test('executionActionType.shell_script is correct', () {
      expect(
        MiscConstants.executionActionType['shell_script'],
        equals(
          'Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction',
        ),
      );
    });
    test('executionActionType.send_email is correct', () {
      expect(
        MiscConstants.executionActionType['send_email'],
        equals(
          'Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.SendEmailAction',
        ),
      );
    });
  });
}
