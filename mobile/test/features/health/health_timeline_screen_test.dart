import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/health/application/health_record_providers.dart';
import 'package:pawmate_mobile/features/health/data/health_record_api.dart';
import 'package:pawmate_mobile/features/health/domain/health_record.dart';
import 'package:pawmate_mobile/features/health/presentation/health_timeline_screen.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';

void main() {
  testWidgets('health timeline shows backend loading state', (tester) async {
    final completer = Completer<HealthRecordListResult>();
    final fakeApi = _FakeHealthRecordApi(
      records: [],
      listHandler: (_, {required accessToken}) => completer.future,
    );
    final router = GoRouter(
      initialLocation: '/health',
      routes: [
        GoRoute(
          path: '/health',
          builder: (context, state) => const HealthTimelineScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith((ref) async => [_samplePet()]),
          healthRecordApiProvider.overrideWith((ref) => fakeApi),
          healthRecordAccessTokenProvider.overrideWith(
            (ref) async => 'health-token',
          ),
          upcomingRemindersProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Đang đồng bộ'), findsWidgets);

    completer.complete(
      const HealthRecordListResult(items: [], total: 0, limit: 20),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có sự kiện'), findsOneWidget);
  });

  testWidgets('health timeline keeps bottom navigation reachable', (
    tester,
  ) async {
    final fakeApi = _FakeHealthRecordApi(
      records: [
        _sampleRecord(
          title: 'Tiêm nhắc lại 5 bệnh',
          note: 'Theo dõi phản ứng trong 24 giờ sau mũi tiêm.',
        ),
      ],
    );
    final router = GoRouter(
      initialLocation: '/health',
      routes: [
        GoRoute(
          path: '/health',
          builder: (context, state) => const HealthTimelineScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Profile target'))),
        ),
        GoRoute(
          path: '/pets',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Pets target'))),
        ),
        GoRoute(
          path: '/vets/list',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Vets target'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith((ref) async => [_samplePet()]),
          healthRecordApiProvider.overrideWith((ref) => fakeApi),
          healthRecordAccessTokenProvider.overrideWith(
            (ref) async => 'health-token',
          ),
          upcomingRemindersProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sức khỏe'), findsOneWidget);
    expect(find.text('Thêm sự kiện'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Vet'), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Tiêm nhắc lại 5 bệnh'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Profile target'), findsOneWidget);
  });

  testWidgets('health timeline shows auth error when token is missing', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/health',
      routes: [
        GoRoute(
          path: '/health',
          builder: (context, state) => const HealthTimelineScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith((ref) async => [_samplePet()]),
          healthRecordAccessTokenProvider.overrideWith((ref) async => null),
          upcomingRemindersProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa đồng bộ được'), findsOneWidget);
    expect(
      find.text('Bạn cần đăng nhập để đồng bộ hồ sơ sức khỏe.'),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('health timeline creates a backend-backed event from the sheet', (
    tester,
  ) async {
    final fakeApi = _FakeHealthRecordApi(records: []);
    final router = GoRouter(
      initialLocation: '/health',
      routes: [
        GoRoute(
          path: '/health',
          builder: (context, state) => const HealthTimelineScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith((ref) async => [_samplePet()]),
          healthRecordApiProvider.overrideWith((ref) => fakeApi),
          healthRecordAccessTokenProvider.overrideWith(
            (ref) async => 'health-token',
          ),
          upcomingRemindersProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có sự kiện'), findsOneWidget);

    await tester.tap(find.text('Thêm sự kiện').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'Bé uống thuốc đúng lịch.',
    );
    await tester.tap(find.text('Lưu sự kiện'));
    await tester.pumpAndSettle();

    expect(fakeApi.createdPetId, 'milo');
    expect(fakeApi.createdAccessToken, 'health-token');
    expect(fakeApi.createdInput?.type, HealthRecordType.vaccination);
    expect(find.text('Bé uống thuốc đúng lịch.'), findsOneWidget);
  });
}

class _FakeHealthRecordApi extends HealthRecordApi {
  _FakeHealthRecordApi({required List<HealthRecord> records, this.listHandler})
    : records = [...records],
      super(Dio());

  final List<HealthRecord> records;
  final Future<HealthRecordListResult> Function(
    HealthRecordListQuery query, {
    required String accessToken,
  })?
  listHandler;
  String? createdPetId;
  String? createdAccessToken;
  CreateHealthRecordInput? createdInput;

  @override
  Future<HealthRecordListResult> listRecords(
    HealthRecordListQuery query, {
    required String accessToken,
  }) async {
    final handler = listHandler;
    if (handler != null) {
      return handler(query, accessToken: accessToken);
    }

    final items = records
        .where((record) => record.petId == query.petId)
        .where((record) => query.type == null || record.type == query.type)
        .toList();

    return HealthRecordListResult(
      items: items,
      total: items.length,
      limit: query.limit,
    );
  }

  @override
  Future<HealthRecord> createRecord(
    String petId,
    CreateHealthRecordInput input, {
    required String accessToken,
  }) async {
    createdPetId = petId;
    createdAccessToken = accessToken;
    createdInput = input;

    final record = _sampleRecord(
      id: 'created-record',
      petId: petId,
      type: input.type,
      title: input.title,
      note: input.note,
    );
    records.insert(0, record);
    return record;
  }
}

PetProfile _samplePet() {
  return PetProfile(
    id: 'milo',
    name: 'Milo',
    species: 'dog',
    breed: 'Poodle',
    gender: 'male',
    dateOfBirth: DateTime(2022, 4, 12),
    weightKg: 6.3,
    healthStatus: 'healthy',
  );
}

HealthRecord _sampleRecord({
  String id = 'record-1',
  String petId = 'milo',
  HealthRecordType type = HealthRecordType.vaccination,
  String title = 'Tiêm phòng',
  String? note,
}) {
  return HealthRecord(
    id: id,
    petId: petId,
    type: type,
    date: '2026-05-05',
    title: title,
    note: note,
    attachments: const [],
    createdAt: '2026-05-05T00:00:00.000Z',
    updatedAt: '2026-05-05T00:00:00.000Z',
  );
}
