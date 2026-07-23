import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

class PawMateApp extends ConsumerWidget {
  const PawMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'PawMate',
      debugShowCheckedModeBanner: false,
      restorationScopeId: 'pawmate-app',
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => AnnotatedRegion(
        value: AppTheme.systemUiOverlayStyle,
        child: child ?? const SizedBox.shrink(),
      ),
      routerConfig: router,
    );
  }
}
