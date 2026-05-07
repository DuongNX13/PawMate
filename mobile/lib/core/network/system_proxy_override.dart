import 'system_proxy_override_stub.dart'
    if (dart.library.io) 'system_proxy_override_io.dart';

Future<void> configureSystemProxyOverride() {
  return configurePlatformSystemProxyOverride();
}
