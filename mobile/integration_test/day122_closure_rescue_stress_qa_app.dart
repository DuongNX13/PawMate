import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_case_detail_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';

import '../test/features/rescue/rescue_test_fixtures.dart';
import 'day122_closure_rescue_state_qa_app.dart' show day119Cases;

// Android, not the launcher, owns the viewport, insets and text scale.
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
      GoRoute(
        path: '/rescue/:caseId',
        builder: (_, state) =>
            RescueCaseDetailScreen(caseId: state.pathParameters['caseId']!),
      ),
    ],
  );
  final source = FakeRescueSource(
    pages: [samplePage(items: day119Cases(longContent: true))],
  );
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
