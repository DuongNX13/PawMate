import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/adoption/application/my_adoption_requests_provider.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_request_chat_models.dart';
import 'package:pawmate_mobile/features/adoption/presentation/my_adoption_requests_screen.dart';

import 'day122_closure_remaining_stress_qa_app.dart' show day119Requests;

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final router = GoRouter(
    initialLocation: '/qa-day122',
    routes: [
      GoRoute(path: '/qa-day122', builder: (_, _) => const _RecoveryMenu()),
      for (final mode in const ['empty', 'error'])
        GoRoute(
          path: '/qa-day122/$mode',
          builder: (_, _) => _RequestsFixture(key: ValueKey(mode), mode: mode),
        ),
      // This marker proves the actual CTA requested /adoption, not that the
      // destination's production content/network was tested.
      GoRoute(
        path: '/adoption',
        builder: (_, _) => const Scaffold(
          body: SafeArea(
            child: Center(child: Text('QA destination /adoption')),
          ),
        ),
      ),
    ],
  );
  runApp(
    ProviderScope(
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
}

class _RecoveryMenu extends StatelessWidget {
  const _RecoveryMenu();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in const ['empty', 'error'])
              FilledButton(
                onPressed: () => context.push('/qa-day122/$mode'),
                child: Text(mode == 'empty' ? 'QA Empty' : 'QA Error'),
              ),
          ],
        ),
      ),
    ),
  );
}

class _RequestsFixture extends StatefulWidget {
  const _RequestsFixture({super.key, required this.mode});
  final String mode;

  @override
  State<_RequestsFixture> createState() => _RequestsFixtureState();
}

class _RequestsFixtureState extends State<_RequestsFixture> {
  int _reads = 0;

  @override
  Widget build(BuildContext context) => ProviderScope(
    retry: (_, _) => null,
    overrides: [
      myAdoptionRequestsProvider.overrideWith((ref) async {
        if (widget.mode == 'empty') return const <AdoptionRequestSummary>[];
        if (++_reads == 1) throw StateError('QA fixture: first read fails');
        return day119Requests().take(1).toList();
      }),
    ],
    child: const MyAdoptionRequestsScreen(),
  );
}
