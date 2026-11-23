import '../test/features/adoption/adoption_test_fixtures.dart';
import '../test/features/adoption/adoption_ui_test_support.dart';
import '../test/features/rescue/rescue_test_fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_text_styles.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/app/theme/app_tokens.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_draft_store.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_models.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_request_chat_models.dart';
import 'package:pawmate_mobile/features/adoption/presentation/shelter_chat_screen.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_location_service.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_map_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_map_canvas.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_map_screen.dart';

// Test-only direct entry points using the pinned Day44 and Day55 fixtures.
// No route, network, location or media production side effects are exercised.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final detailJson = adoptionDetailJson();
  detailJson['heroMedia'] = adoptionMediaJson(publicUrl: null);
  runApp(
    ProviderScope(
      overrides: [
        rescueApiProvider.overrideWithValue(
          FakeRescueSource(
            pages: [samplePage(items: _figmaCases(day118PetMedia: true))],
          ),
        ),
        rescueClockProvider.overrideWithValue(fixedRescueClock()),
        rescueLocationServiceProvider.overrideWithValue(
          const _GoldenLocationService(),
        ),
        rescueMapCanvasBuilderProvider.overrideWithValue(_goldenMapBuilder),
        adoptionSourceProvider.overrideWithValue(
          FakeAdoptionUiSource(
            detail: AdoptionListingDetail.fromJson(detailJson),
          ),
        ),
        adoptionRequestChatSourceProvider.overrideWithValue(
          _GoldenRequestChatSource(),
        ),
        adoptionRequestChatDraftStoreProvider.overrideWithValue(
          _GoldenDraftStore(),
        ),
        adoptionRequestListSourceProvider.overrideWithValue(
          _GoldenRequestListSource(),
        ),
        authSessionSnapshotProvider.overrideWithValue(
          const AsyncValue.data(_session),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const _QaLauncher(),
      ),
    ),
  );
}

class _QaLauncher extends StatelessWidget {
  const _QaLauncher();

  @override
  Widget build(BuildContext context) {
    void open(Widget screen) {
      Navigator.of(
        context,
      ).push<void>(MaterialPageRoute<void>(builder: (_) => screen));
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => open(const RescueMapScreen()),
                child: const Text('QA_OPEN_RESCUE_MAP'),
              ),
              TextButton(
                onPressed: () =>
                    open(const ShelterChatScreen(threadId: 'thread-1')),
                child: const Text('QA_OPEN_ADOPTION_CHAT'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _goldenMapBuilder(
  RescueMapLocation center,
  List<RescueCaseSummary> items,
  ValueChanged<String> onMarkerTap,
  ValueChanged<Object> onMapUnavailable,
) {
  return ColoredBox(
    color: AppColors.lightBeige,
    child: CustomPaint(
      painter: const _GoldenMapPainter(),
      child: Stack(
        children: [
          Positioned(
            left: 160,
            top: 311,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: AppColors.deepGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          for (var index = 0; index < items.length; index++)
            Positioned(
              left: index == 0 ? 118 : 194,
              top: index == 0 ? 360 : 312,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8,
                      vertical: AppSpacing.s4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.deepGreen,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      items[index].status.label,
                      style: AppTextStyles.micro(color: AppColors.white),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Semantics(
                    button: true,
                    label:
                        'Khu vực ước tính của ${items[index].petName}, ${items[index].publicLocation.areaLabel}',
                    child: IconButton.filled(
                      key: ValueKey('golden-marker-${items[index].caseId}'),
                      tooltip: 'Khu vực ${items[index].petName}',
                      onPressed: () => onMarkerTap(items[index].caseId),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.deepGreen,
                        foregroundColor: AppColors.white,
                        side: const BorderSide(
                          color: AppColors.white,
                          width: 3,
                        ),
                      ),
                      icon: const Icon(Icons.pets_rounded),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _GoldenLocationService implements RescueLocationService {
  const _GoldenLocationService();

  @override
  Future<RescueMapLocation> resolveCurrentLocation({
    RescueLocationRequest? request,
  }) async => const RescueMapLocation(latitude: 10.7769, longitude: 106.7009);
}

class _GoldenMapPainter extends CustomPainter {
  const _GoldenMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final uncertainty = Paint()
      ..color = AppColors.surfaceContainer.withValues(alpha: 0.42)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = AppColors.mint
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const center = Offset(200, 340);
    canvas.drawCircle(center, 150, uncertainty);
    canvas.drawCircle(center, 150, border);
  }

  @override
  bool shouldRepaint(covariant _GoldenMapPainter oldDelegate) => false;
}

List<RescueCaseSummary> _figmaCases({bool day118PetMedia = false}) {
  final source = sampleCases().take(2).toList(growable: false);
  final assets = day118PetMedia
      ? const [
          'assets/images/pets/home_adoption_golden.png',
          'assets/images/pets/p1_05_mochi.png',
        ]
      : const [
          'assets/images/rescue/p2_05_lulu.png',
          'assets/images/rescue/p2_05_muc.png',
        ];
  return [
    for (var index = 0; index < source.length; index++)
      RescueCaseSummary(
        caseId: source[index].caseId,
        petName: source[index].petName,
        species: source[index].species,
        status: source[index].status,
        lostAt: source[index].lostAt,
        publicLocation: source[index].publicLocation,
        media: [
          RescuePublicMedia(
            mediaId: 'map-media-$index',
            mimeType: 'image/png',
            publicUrl: Uri.parse('asset:${assets[index]}'),
            createdAt: source[index].createdAt,
          ),
        ],
        commentCount: source[index].commentCount,
        createdAt: source[index].createdAt,
        updatedAt: source[index].updatedAt,
        breedOrColor: source[index].breedOrColor,
        ageLabel: source[index].ageLabel,
        distanceMeters: source[index].distanceMeters,
      ),
  ];
}

class _GoldenRequestListSource implements AdoptionRequestListSource {
  @override
  Future<List<AdoptionRequestSummary>> listMyRequests({
    required String accessToken,
  }) async => [
    AdoptionRequestSummary.fromJson({
      'requestId': 'request-expired-1',
      'listingId': 'listing-expired-1',
      'petName': 'Mochi',
      'status': 'reviewing',
      'listingAvailability': 'expired',
      'threadId': 'thread-1',
      'createdAt': '2026-07-28T05:00:00.000Z',
      'updatedAt': '2026-09-18T05:00:00.000Z',
    }),
  ];
}

const _session = AuthSession(
  user: AuthUser(
    id: 'adopter-1',
    email: 'golden@example.com',
    authProvider: 'email',
    emailVerified: true,
  ),
  accessToken: 'golden-token',
  refreshToken: 'golden-refresh',
  accessTokenExpiresAt: '2030-01-01T00:00:00.000Z',
  refreshTokenExpiresAt: '2030-01-02T00:00:00.000Z',
);

class _GoldenRequestChatSource implements AdoptionRequestChatSource {
  @override
  Future<AdoptionRequestResult> createRequest({
    required String accessToken,
    required String listingId,
    required AdoptionRequestDraft draft,
    required String idempotencyKey,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdoptionChatPage> readChat({
    required String accessToken,
    required String threadId,
    String? cursor,
    int limit = 50,
  }) async {
    return AdoptionChatPage(
      messages: [
        AdoptionChatMessage(
          messageId: 'message-1',
          threadId: threadId,
          senderUserId: 'shelter-1',
          body:
              'Chào bạn! Cảm ơn bạn đã quan tâm đến bé Mochi. Chúng mình đã nhận được yêu cầu nhận nuôi của bạn và đang xem xét hồ sơ.',
          media: const [],
          createdAt: DateTime.utc(2026, 7, 28, 3, 10),
        ),
      ],
      thread: AdoptionChatThread(
        threadId: threadId,
        requestId: 'request-1',
        participantRole: AdoptionChatParticipantRole.adopter,
        lastReadAt: DateTime.utc(2026, 7, 28, 3, 10),
        unreadCount: 0,
      ),
      hasMore: false,
      limit: limit,
    );
  }

  @override
  Future<AdoptionChatReadState> markRead({
    required String accessToken,
    required String threadId,
    required String throughMessageId,
  }) async => AdoptionChatReadState(
    threadId: threadId,
    lastReadAt: DateTime.utc(2026, 7, 28, 3, 12),
    unreadCount: 0,
  );

  @override
  Future<AdoptionChatMessage> sendMessage({
    required String accessToken,
    required String threadId,
    required String body,
    required List<String> mediaIds,
    required String idempotencyKey,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdoptionChatDraftMedia> uploadChatMedia({
    required String accessToken,
    required String threadId,
    required AdoptionChatDraftMedia media,
    required ValueChanged<double> onProgress,
  }) {
    throw UnimplementedError();
  }
}

class _GoldenDraftStore implements AdoptionRequestChatDraftStore {
  @override
  Future<AdoptionRequestDraft> readRequestDraft({
    required String userId,
    required String listingId,
  }) async => const AdoptionRequestDraft();

  @override
  Future<AdoptionChatDraft> readChatDraft({
    required String userId,
    required String threadId,
  }) async => const AdoptionChatDraft();

  @override
  Future<AdoptionChatContext?> readChatContext({
    required String userId,
    required String threadId,
  }) async => const AdoptionChatContext(
    listingId: 'listing-1',
    petName: 'Mochi',
    shelterId: 'shelter-1',
  );

  @override
  Future<void> saveRequestDraft({
    required String userId,
    required String listingId,
    required AdoptionRequestDraft draft,
  }) async {}

  @override
  Future<void> clearRequestDraft({
    required String userId,
    required String listingId,
  }) async {}

  @override
  Future<void> saveChatDraft({
    required String userId,
    required String threadId,
    required AdoptionChatDraft draft,
  }) async {}

  @override
  Future<void> clearChatDraft({
    required String userId,
    required String threadId,
  }) async {}

  @override
  Future<void> saveChatContext({
    required String userId,
    required String threadId,
    required AdoptionChatContext context,
  }) async {}
}
