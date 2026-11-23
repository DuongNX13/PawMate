import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/health/application/health_record_providers.dart';
import 'package:pawmate_mobile/features/health/data/health_record_api.dart';
import 'package:pawmate_mobile/features/health/domain/health_record.dart';
import 'package:pawmate_mobile/features/health/presentation/add_health_event_screen.dart';
import 'package:pawmate_mobile/features/health/presentation/health_timeline_screen.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';
import '../../test_support/day116_capture.dart';
import '../../test_support/ui_test_helpers.dart';

const _note = 'Giữ ghi chú của bé khi mất mạng, sau đó lưu lại đúng một lần.';
const _error = 'Mất kết nối. Dữ liệu vẫn được giữ để thử lại.';

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets(
      'D116 R10 ST-11 ST-12 P1-13 text$scale IME failure draft retry and timeline result',
      (tester) async {
        await setTestViewport(tester, size: const Size(320, 568));
        final source = _HealthSource();
        final router = GoRouter(
          initialLocation: '/health/events/new?petId=r10-pet',
          routes: [
            GoRoute(
              path: '/health',
              builder: (context, state) => const HealthTimelineScreen(),
            ),
            GoRoute(
              path: '/health/events/new',
              builder: (context, state) => AddHealthEventScreen(
                initialPetId: state.uri.queryParameters['petId'],
                initialDate: DateTime(2026, 10, 14),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              petBackendListProvider.overrideWith(
                (ref) async => [
                  PetProfile(
                    id: 'r10-pet',
                    name: 'Mochi',
                    species: 'dog',
                    breed: 'Poodle',
                    gender: 'male',
                    dateOfBirth: DateTime(2022, 4, 12),
                    weightKg: 6.3,
                    healthStatus: 'healthy',
                  ),
                ],
              ),
              healthRecordApiProvider.overrideWithValue(source),
              healthRecordAccessTokenProvider.overrideWith(
                (ref) async => 'fixture-token',
              ),
              upcomingRemindersProvider.overrideWith((ref) async => const []),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light(),
              builder: testTextScaleBuilder(scale),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await setKeyboardInset(tester, bottom: 300);
        final clinic = find.byKey(const Key('add-health-clinic-input'));
        final note = find.byKey(const Key('add-health-note-input'));
        final save = find.byKey(const Key('add-health-save-button'));
        Future<Offset> reveal(Finder target) async {
          await tester.scrollUntilVisible(
            target,
            160,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 40,
          );
          await tester.pumpAndSettle();
          // The five-line input is taller than the IME-reduced viewport at
          // text2. Its center need not be visible. Prove a point on its actual
          // visible portion reaches the same render subtree instead.
          final bounds = tester.getRect(target);
          final visible = bounds.intersect(const Rect.fromLTWH(0, 0, 320, 268));
          expect(visible.width, greaterThan(0));
          expect(visible.height, greaterThan(0));
          final render = tester.renderObject<RenderObject>(target);
          final point = visible.center;
          final hit = tester.hitTestOnBinding(point);
          final reachesTarget = hit.path.any((entry) {
            if (entry.target is! RenderObject) return false;
            RenderObject? current = entry.target as RenderObject;
            while (current != null) {
              if (identical(current, render)) return true;
              current = current.parent;
            }
            return false;
          });
          expect(
            reachesTarget,
            isTrue,
            reason: 'Visible point must hit target',
          );
          return point;
        }

        await tester.tapAt(await reveal(clinic));
        await tester.enterText(clinic, 'PetCare Elite');
        await tester.tapAt(await reveal(note));
        await tester.enterText(note, _note);
        await reveal(save);
        expect(tester.getRect(save).bottom, lessThanOrEqualTo(268));
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(source.inputs.length, 1);
        expect(source.records, isEmpty);
        expect(source.petIds, ['r10-pet']);
        expect(source.inputs.single.note, _note);
        expect(source.inputs.single.vetId, 'PetCare Elite');
        expect(source.inputs.single.time, '09:30');
        expect(source.inputs.single.type, HealthRecordType.vaccination);
        expect(source.inputs.single.date, DateTime(2026, 10, 14, 9, 30));
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/health/events/new',
        );
        await reveal(find.text(_error));
        final errorRect = tester.getRect(find.text(_error));
        expect(errorRect.top, greaterThanOrEqualTo(0));
        expect(errorRect.bottom, lessThanOrEqualTo(268));
        await captureDay116(
          tester,
          'R10-P113-error-text${scale.toString().replaceAll('.', '-')}',
        );

        // No input re-entry: a real retry must submit the retained draft.
        await reveal(save);
        expect(tester.getRect(save).top, greaterThanOrEqualTo(0));
        expect(tester.getRect(save).bottom, lessThanOrEqualTo(268));
        await captureDay116(
          tester,
          'R10-P113-retry-cta-text${scale.toString().replaceAll('.', '-')}',
        );
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(source.inputs.length, 2);
        expect(source.inputs[1].toJson(), source.inputs[0].toJson());
        expect(source.petIds, ['r10-pet', 'r10-pet']);
        expect(source.records, hasLength(1));
        expect(source.records.single.note, _note);
        expect(router.routerDelegate.currentConfiguration.uri.path, '/health');
        await setKeyboardInset(tester, bottom: 0);
        await tester.pumpAndSettle();
        expect(find.byType(HealthTimelineScreen), findsOneWidget);
        await reveal(find.text(_note));
        expect(find.text(_error), findsNothing);
        expectNoFlutterOverflow(tester);
        await captureDay116(
          tester,
          'R10-P113-success-text${scale.toString().replaceAll('.', '-')}',
        );
      },
    );
  }
}

/// In-memory API boundary, not a claim of backend persistence or live network.
class _HealthSource extends HealthRecordApi {
  _HealthSource() : super(Dio());
  final inputs = <CreateHealthRecordInput>[];
  final petIds = <String>[];
  final records = <HealthRecord>[];

  @override
  Future<HealthRecord> createRecord(
    String petId,
    CreateHealthRecordInput input, {
    required String accessToken,
  }) async {
    expect(accessToken, 'fixture-token');
    inputs.add(input);
    petIds.add(petId);
    if (inputs.length == 1) {
      throw const HealthRecordApiException(_error, code: 'NETWORK_ERROR');
    }
    final record = HealthRecord(
      id: 'r10-record',
      petId: petId,
      type: input.type,
      date: input.date.toIso8601String(),
      time: input.time,
      title: input.title,
      note: input.note,
      vetId: input.vetId,
      attachments: const [],
      createdAt: '2026-10-14T02:30:00Z',
      updatedAt: '2026-10-14T02:30:00Z',
    );
    records.add(record);
    return record;
  }

  @override
  Future<HealthRecordListResult> listRecords(
    HealthRecordListQuery query, {
    required String accessToken,
  }) async {
    expect(accessToken, 'fixture-token');
    return HealthRecordListResult(
      items: records
          .where(
            (r) =>
                r.petId == query.petId &&
                (query.type == null || r.type == query.type),
          )
          .toList(),
      total: records.length,
      limit: query.limit,
    );
  }
}
