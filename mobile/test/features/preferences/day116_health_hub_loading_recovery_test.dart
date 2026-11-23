import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_skeleton.dart';
import 'package:pawmate_mobile/features/health_hub/application/health_knowledge_provider.dart';
import 'package:pawmate_mobile/features/health_hub/domain/health_knowledge.dart';
import 'package:pawmate_mobile/features/health_hub/presentation/health_hub_screen.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/data/pet_api.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';

import '../../test_support/day116_capture.dart';
import '../../test_support/ui_test_helpers.dart';

const _pet = PetProfile(
  id: 'r22-pet',
  name: 'Mochi R22',
  species: 'dog',
  breed: 'Poodle',
  gender: 'unknown',
  healthStatus: 'healthy',
);

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final scale in [1.0, 1.3, 2.0]) {
    for (final state in ['ST-01', 'ST-02', 'ST-03']) {
      testWidgets('D116 R22 $state P2-13 pet boundary recovery text$scale', (
        tester,
      ) async {
        await setTestViewport(tester, size: const Size(320, 568));
        final semantics = tester.ensureSemantics();
        try {
          final source = _Source();
          final container = ProviderContainer(
            retry: (_, _) => null,
            overrides: [
              petApiProvider.overrideWithValue(source),
              petAccessTokenProvider.overrideWith((_) async => 'fixture-token'),
            ],
          );
          addTearDown(container.dispose);
          container
              .read(healthKnowledgeFilterProvider.notifier)
              .select(HealthKnowledgeFilter.nutrition);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AppTheme.light(),
                builder: testTextScaleBuilder(scale),
                home: const HealthHubScreen(),
              ),
            ),
          );
          await tester.pump();
          expect(source.calls, 1);
          expect(
            find.byKey(const Key('health-hub-pet-loading')),
            findsOneWidget,
          );
          expect(find.byType(PawMateSkeleton), findsWidgets);
          expect(find.byKey(const Key('health-hub-empty-pet')), findsNothing);
          final stem =
              'R22-$state-P213-text${scale.toString().replaceAll('.', '-')}';
          if (state == 'ST-03') {
            await captureDay116(tester, '$stem-pending');
          } else {
            source.pending.completeError(
              PetApiException(
                state == 'ST-01'
                    ? 'Không có kết nối mạng.'
                    : 'Máy chủ tạm thời chưa sẵn sàng.',
                code: state == 'ST-01' ? 'NETWORK_ERROR' : 'SERVER_ERROR',
                statusCode: state == 'ST-02' ? 503 : null,
              ),
            );
            await tester.pumpAndSettle();
            final error = find.byKey(const Key('health-hub-pet-error'));
            expect(error, findsOneWidget);
            expect(find.byKey(const Key('health-hub-empty-pet')), findsNothing);
            expect(
              find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.liveRegion == true,
              ),
              findsWidgets,
            );
            await captureDay116(tester, '$stem-failed');
            // Bundled knowledge remains available during a pet API failure.
            final cached = find.text('Duy trì cân nặng khỏe mạnh cho thú cưng');
            await tester.scrollUntilVisible(
              cached,
              180,
              scrollable:
                  find.byKey(const Key('health-hub-scroll')).evaluate().isEmpty
                  ? find.byType(Scrollable).first
                  : find
                        .descendant(
                          of: find.byKey(const Key('health-hub-scroll')),
                          matching: find.byType(Scrollable),
                        )
                        .first,
            );
            await tester.pumpAndSettle();
            expect(cached.hitTestable(), findsOneWidget);
            expect(
              container.read(healthKnowledgeFilterProvider),
              HealthKnowledgeFilter.nutrition,
            );
            source.pending = Completer<List<PetProfile>>();
            final retry = find.widgetWithText(PawMateButton, 'Thử lại');
            await tester.scrollUntilVisible(
              retry,
              -180,
              scrollable: find
                  .descendant(
                    of: find.byKey(const Key('health-hub-scroll')),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await tester.pumpAndSettle();
            expect(retry.hitTestable(), findsOneWidget);
            expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
            await tester.tap(retry);
            await tester.pump();
            expect(source.calls, 2);
            // The failed panel is taller than the pending card. The outer
            // lazy list retains its offset after retry; observe the loading
            // owner at its actual position rather than an offscreen child.
            tester
                .state<ScrollableState>(
                  find
                      .descendant(
                        of: find.byKey(const Key('health-hub-scroll')),
                        matching: find.byType(Scrollable),
                      )
                      .first,
                )
                .position
                .jumpTo(0);
            await tester.pump();
            expect(
              find.byKey(const Key('health-hub-pet-loading')),
              findsOneWidget,
            );
          }
          source.pending.complete([_pet]);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('health-hub-pet-loading')), findsNothing);
          expect(find.byKey(const Key('health-hub-pet-error')), findsNothing);
          expect(find.text('Mochi R22'), findsOneWidget);
          expect(container.read(petListProvider).single.id, _pet.id);
          expect(
            container.read(healthKnowledgeFilterProvider),
            HealthKnowledgeFilter.nutrition,
          );
          await captureDay116(tester, '$stem-ready');
          expectNoFlutterOverflow(tester);
        } finally {
          semantics.dispose();
        }
      });
    }
  }
}

class _Source extends PetApi {
  _Source() : super(Dio());
  var pending = Completer<List<PetProfile>>();
  int calls = 0;
  @override
  Future<List<PetProfile>> listPets({required String accessToken}) {
    expect(accessToken, 'fixture-token');
    calls++;
    return pending.future;
  }
}
