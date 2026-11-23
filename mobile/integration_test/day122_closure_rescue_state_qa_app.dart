import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';

import '../test/features/rescue/rescue_test_fixtures.dart';

// Isolated QA launcher; the build verifies this part against Day 119.
part 'day122_closure_rescue_state_fixture.part.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final router = GoRouter(
    initialLocation: '/rescue',
    restorationScopeId: 'day119-router',
    routes: [
      GoRoute(
        path: '/rescue',
        builder: (_, _) => const RescueHomeScreen(
          browseEnabled: true,
          createEnabled: true,
          mapPreviewAsset: 'assets/images/rescue/p2_01_map.png',
        ),
      ),
    ],
  );
  final source = FakeRescueSource(pages: [samplePage(items: day119Cases())]);
  runApp(
    ProviderScope(
      overrides: [
        rescueApiProvider.overrideWithValue(source),
        rescueClockProvider.overrideWithValue(fixedRescueClock()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
}
