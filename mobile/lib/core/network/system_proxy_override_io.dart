import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http_proxy/http_proxy.dart';

Future<void> configurePlatformSystemProxyOverride() async {
  const enabled = bool.fromEnvironment('PAWMATE_ENABLE_SYSTEM_PROXY');
  if (!enabled) {
    return;
  }

  try {
    final httpProxy = await HttpProxy.createHttpProxy();
    HttpOverrides.global = httpProxy;
    debugPrint('PawMate system proxy override enabled for mobile smoke.');
  } catch (error, stackTrace) {
    debugPrint('PawMate system proxy override failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
