import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/presentation/register_screen.dart';
import 'package:pawmate_mobile/features/vets/application/vet_providers.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_detail_screen.dart';

// Manual/native QA only. No test driver, synthetic insets, auth, or submission.
// The login destination is a route oracle; clinic data is offline fixture data.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(
    ProviderScope(
      overrides: [
        vetDetailProvider(_clinic.id).overrideWith((ref) async => _clinic),
        vetReviewListProvider(_clinic.id).overrideWith((ref) async => _reviews),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('vi', 'VN'),
        supportedLocales: const [Locale('vi', 'VN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: _router,
      ),
    ),
  );
}

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const _Launcher()),
    GoRoute(path: '/auth/register', builder: (_, _) => const RegisterScreen()),
    GoRoute(
      path: '/auth/login',
      builder: (_, _) =>
          const Scaffold(body: Center(child: Text('QA_LOGIN_DESTINATION'))),
    ),
    GoRoute(
      path: '/vets/:vetId',
      builder: (_, state) =>
          VetDetailScreen(vetId: state.pathParameters['vetId']!),
    ),
  ],
);

class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('D122 Safe-area Back QA')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: () => context.push('/auth/register'),
            child: const Text('QA_OPEN_REGISTER'),
          ),
          FilledButton(
            onPressed: () => context.push('/vets/${_clinic.id}'),
            child: const Text('QA_OPEN_VET'),
          ),
        ],
      ),
    ),
  );
}

const _clinic = VetDetail(
  id: 'pethome-q7',
  name: 'PetHome Q7',
  city: 'TP Hồ Chí Minh',
  district: 'Phú Mỹ, Quận 7',
  address: '120 Nguyễn Lương Bằng',
  phone: '',
  summary: 'Cấp cứu 24/7 và chăm sóc định kỳ cho thú cưng.',
  services: ['Tiêm phòng', 'Cấp cứu 24/7', 'Khám tổng quát'],
  seedRank: 1,
  averageRating: 4.8,
  reviewCount: 120,
  is24h: false,
  isOpen: true,
  readyForMap: true,
  latitude: 10.778,
  longitude: 106.701,
  openHours: ['08:00 - 21:00'],
  photoUrls: [],
  source: VetSource(
    url: 'https://pawmate.test',
    list: 'PawMate seeded clinic',
    priorityTier: 'P0',
    enrichmentStatus: 'verified',
    selectionReason: 'day122-back-triage',
  ),
);

const _reviews = VetReviewResult(
  items: [],
  summary: VetReviewSummary(
    averageRating: 4.8,
    reviewCount: 120,
    distribution: {},
  ),
  total: 120,
  limit: 20,
);
