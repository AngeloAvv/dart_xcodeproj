// Port of Xcodeproj::Constants PRODUCT_TYPE_UTI and PRODUCT_UTI_EXTENSIONS
// static const Map, not enums
// Ruby uses Symbol keys (:application); Dart uses String keys ('application')
class ProductTypes {
  ProductTypes._();

  /// The uniform type identifier of various product types.
  /// Ruby: PRODUCT_TYPE_UTI — 21 entries
  /// Keys: product type name (Ruby Symbol converted to String)
  /// Values: UTI string
  static const Map<String, String> productTypeUti = {
    'application': 'com.apple.product-type.application',
    'application_on_demand_install_capable':
        'com.apple.product-type.application.on-demand-install-capable',
    'framework': 'com.apple.product-type.framework',
    'dynamic_library': 'com.apple.product-type.library.dynamic',
    'static_library': 'com.apple.product-type.library.static',
    'bundle': 'com.apple.product-type.bundle',
    'octest_bundle': 'com.apple.product-type.bundle',
    'unit_test_bundle': 'com.apple.product-type.bundle.unit-test',
    'ui_test_bundle': 'com.apple.product-type.bundle.ui-testing',
    'app_extension': 'com.apple.product-type.app-extension',
    'command_line_tool': 'com.apple.product-type.tool',
    'watch_app': 'com.apple.product-type.application.watchapp',
    'watch2_app': 'com.apple.product-type.application.watchapp2',
    'watch2_app_container':
        'com.apple.product-type.application.watchapp2-container',
    'watch_extension': 'com.apple.product-type.watchkit-extension',
    'watch2_extension': 'com.apple.product-type.watchkit2-extension',
    'tv_extension': 'com.apple.product-type.tv-app-extension',
    'messages_application': 'com.apple.product-type.application.messages',
    'messages_extension': 'com.apple.product-type.app-extension.messages',
    'sticker_pack':
        'com.apple.product-type.app-extension.messages-sticker-pack',
    'xpc_service': 'com.apple.product-type.xpc-service',
  };

  /// The extensions for the various product UTIs.
  /// Ruby: PRODUCT_UTI_EXTENSIONS — 16 entries
  /// Keys: product type name (Ruby Symbol converted to String)
  /// Values: file extension without leading dot
  static const Map<String, String> productUtiExtensions = {
    'application': 'app',
    'application_on_demand_install_capable': 'app',
    'framework': 'framework',
    'dynamic_library': 'dylib',
    'static_library': 'a',
    'bundle': 'bundle',
    'octest_bundle': 'octest',
    'unit_test_bundle': 'xctest',
    'ui_test_bundle': 'xctest',
    'app_extension': 'appex',
    'messages_application': 'app',
    'messages_extension': 'appex',
    'sticker_pack': 'appex',
    'watch2_extension': 'appex',
    'watch2_app': 'app',
    'watch2_app_container': 'app',
  };
}
