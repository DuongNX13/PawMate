// Offline QA launcher; production surfaces, isolated stores, no backend writes.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_runtime_providers.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_draft_store.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_request_chat_models.dart';
import 'package:pawmate_mobile/features/adoption/presentation/shelter_chat_screen.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/data/pet_api.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/create_pet_screen.dart';
import 'package:pawmate_mobile/features/preferences/data/preference_api.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _actor = 'qa-adopter';
const _thread = 'qa-thread';
const _token = 'qa-offline-only';
final _time = DateTime.utc(2026, 7, 16, 9);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final prefs = await SharedPreferences.getInstance();
  final draftStore = SharedPreferencesAdoptionRequestChatDraftStore();
  await draftStore.saveChatContext(
    userId: _actor,
    threadId: _thread,
    context: const AdoptionChatContext(
      listingId: 'qa-listing',
      petName: 'Mochi',
      shelterId: 'qa-shelter',
    ),
  );
  final pet = _PetApi();
  final chat = _ChatSource();
  const destinations = {
    'QA B2 Pet Edit': '/pets/mochi/edit',
    'QA B2 Shelter Chat': '/adoption/chat/qa-thread',
    'QA B2 Onboarding': '/onboarding',
  };
  final router = GoRouter(
    initialLocation: '/qa-b2',
    routes: [
      GoRoute(
        path: '/qa-b2',
        builder: (context, _) => Scaffold(
          body: SafeArea(
            child: ListView(
              children: [
                for (final item in destinations.entries)
                  FilledButton(
                    onPressed: () => context.push(item.value),
                    child: Text(item.key),
                  ),
              ],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/pets/mochi/edit',
        builder: (_, _) => const CreatePetScreen(petId: 'mochi'),
      ),
      GoRoute(
        path: '/pets/mochi',
        builder: (_, _) =>
            _receipt('QA PET SAVED: ${pet.lastBreed ?? "NO_WRITE"}'),
      ),
      GoRoute(
        path: '/adoption/chat/qa-thread',
        builder: (_, _) => const ShelterChatScreen(threadId: _thread),
      ),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/auth/login', builder: (_, _) => _receipt('QA LOGIN')),
      GoRoute(
        path: '/auth/register',
        builder: (_, _) => _receipt(
          'QA REGISTER: ${prefs.getString("onboardingDraftPetName") ?? "NO_DRAFT"}',
        ),
      ),
    ],
  );
  runApp(
    ProviderScope(
      overrides: [
        authSessionSnapshotProvider.overrideWithValue(
          const AsyncData(
            AuthSession(
              user: AuthUser(
                id: _actor,
                email: 'fixture@example.test',
                authProvider: 'email',
                emailVerified: true,
              ),
              accessToken: _token,
              refreshToken: _token,
              accessTokenExpiresAt: '2099-01-01T00:00:00Z',
              refreshTokenExpiresAt: '2099-01-02T00:00:00Z',
            ),
          ),
        ),
        authAccessTokenProvider.overrideWith((_) async => _token),
        petSessionRevisionProvider.overrideWithValue(0),
        petApiProvider.overrideWithValue(pet),
        adoptionSessionRevisionProvider.overrideWithValue(0),
        adoptionClockProvider.overrideWithValue(() => _time),
        adoptionRequestChatDraftStoreProvider.overrideWithValue(draftStore),
        adoptionRequestChatSourceProvider.overrideWithValue(chat),
        preferenceSourceProvider.overrideWithValue(_Privacy()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
}

Widget _receipt(String text) => Scaffold(
  body: SafeArea(child: Center(child: Text(text))),
);

class _PetApi extends PetApi {
  _PetApi() : super(Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1')));
  PetProfile _current = PetProfile(
    id: 'mochi',
    name: 'Mochi',
    species: 'dog',
    breed: 'Golden Retriever',
    gender: 'male',
    dateOfBirth: DateTime(2022, 4, 12),
    weightKg: 12.4,
    healthStatus: 'healthy',
    avatarPath: 'assets/images/pets/home_adoption_golden.png',
    color: 'Vàng kem',
    microchip: 'MC-8293-128',
    isNeutered: true,
  );
  String? lastBreed;

  @override
  Future<List<PetProfile>> listPets({required String accessToken}) async => [
    _current,
  ];

  @override
  Future<PetProfile> updatePet(
    String petId,
    UpdatePetProfileInput input, {
    required String accessToken,
  }) async {
    if (petId != _current.id || accessToken != _token || lastBreed != null) {
      throw StateError('Wrong or duplicate QA pet update');
    }
    lastBreed = input.breed;
    return _current = _current.copyWith(breed: input.breed);
  }
}

class _ChatSource implements AdoptionRequestChatSource {
  @override
  Future<AdoptionChatPage> readChat({
    required String accessToken,
    required String threadId,
    String? cursor,
    int limit = 50,
  }) async => AdoptionChatPage(
    messages: [_message('qa-greeting', 'qa-shelter', 'QA: Chào bạn và Mochi.')],
    thread: AdoptionChatThread(
      threadId: _thread,
      requestId: 'qa-request',
      participantRole: AdoptionChatParticipantRole.adopter,
      lastReadAt: _time,
      unreadCount: 0,
    ),
    hasMore: false,
    limit: limit,
  );

  @override
  Future<AdoptionChatReadState> markRead({
    required String accessToken,
    required String threadId,
    required String throughMessageId,
  }) async => AdoptionChatReadState(
    threadId: threadId,
    lastReadAt: _time,
    unreadCount: 0,
  );

  @override
  Future<AdoptionChatMessage> sendMessage({
    required String accessToken,
    required String threadId,
    required String body,
    required List<String> mediaIds,
    required String idempotencyKey,
  }) async {
    if (threadId != _thread || accessToken != _token || mediaIds.isNotEmpty) {
      throw StateError('Wrong QA chat destination');
    }
    return _message('qa-sent-1', _actor, body);
  }

  AdoptionChatMessage _message(String id, String sender, String body) =>
      AdoptionChatMessage(
        messageId: id,
        threadId: _thread,
        senderUserId: sender,
        body: body,
        media: [],
        createdAt: sender == _actor
            ? _time.add(const Duration(seconds: 1))
            : _time,
      );

  @override
  Future<AdoptionRequestResult> createRequest({
    required String accessToken,
    required String listingId,
    required AdoptionRequestDraft draft,
    required String idempotencyKey,
  }) => throw UnsupportedError('Outside B2');

  @override
  Future<AdoptionChatDraftMedia> uploadChatMedia({
    required String accessToken,
    required String threadId,
    required AdoptionChatDraftMedia media,
    required ValueChanged<double> onProgress,
  }) => throw UnsupportedError('Outside B2');
}

class _Privacy implements PreferenceSource {
  @override
  Future<PrivacyDefaults> getPrivacyDefaults({
    required String accessToken,
  }) async => PrivacyDefaults(
    userId: _actor,
    version: 1,
    hideHouseNumber: true,
    hidePhoneByDefault: true,
    reviewMediaBeforePublish: true,
    updatedAt: _time,
  );

  @override
  Future<PrivacyDefaults> updatePrivacyDefaults(
    PrivacyDefaults value, {
    required String accessToken,
  }) => throw UnsupportedError('Outside B2');

  @override
  Future<NotificationPreferences> getNotificationPreferences({
    required String accessToken,
  }) => throw UnsupportedError('Outside B2');

  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences value, {
    required String accessToken,
  }) => throw UnsupportedError('Outside B2');
}
