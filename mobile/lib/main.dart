import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/pawmate_app.dart';
import 'core/network/system_proxy_override.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureSystemProxyOverride();
  runApp(const ProviderScope(child: PawMateApp()));
}
