import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_status_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_status_screen.dart';

import '../test/features/rescue/rescue_comment_test_fixtures.dart';
import '../test/features/rescue/rescue_test_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<bool> prepareScreenshot() async {
    try {
      await binding.convertFlutterSurfaceToImage();
      return true;
    } on MissingPluginException catch (error) {
      debugPrint('ANDROID_SCREENSHOT_SKIPPED: $error');
      return false;
    }
  }

  testWidgets(
    'Day 48 Android owner conflict requires detail refresh before retry',
    (tester) async {
      final source = _DeviceStatusSource();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescueApiProvider.overrideWithValue(
              FakeRescueSource(
                detail: sampleCaseDetail(canUpdateStatus: true, version: 2),
              ),
            ),
            rescueStatusSourceProvider.overrideWithValue(source),
            authAccessTokenProvider.overrideWith(
              (ref) async => 'day48-owner-token',
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: const RescueStatusScreen(caseId: sampleCommentCaseId),
          ),
        ),
      );
      final canTakeScreenshot = await prepareScreenshot();
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('rescue-status-confirm-safe')),
      );
      await tester.tap(find.byKey(const Key('rescue-status-confirm-safe')));
      await tester.pump();
      await tester.tap(find.text('Lưu trạng thái'));
      await tester.pumpAndSettle();

      expect(source.calls, 1);
      expect(find.text('Tải lại'), findsOneWidget);
      expect(find.textContaining('thay đổi ở thiết bị khác'), findsOneWidget);
      await tester.binding.delayed(const Duration(milliseconds: 50));
      expect(source.calls, 1);

      source.conflict = false;
      await tester.ensureVisible(find.text('Tải lại'));
      await tester.tap(find.text('Tải lại'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('rescue-status-confirm-safe')),
      );
      await tester.tap(find.byKey(const Key('rescue-status-confirm-safe')));
      await tester.pump();
      await tester.tap(find.text('Lưu trạng thái'));
      await tester.pumpAndSettle();

      expect(source.calls, 2);
      expect(source.versions, [2, 2]);
      expect(find.text('Đã cập nhật thành “Đã thấy”'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (canTakeScreenshot) {
        await binding.takeScreenshot('day48-rescue-status-conflict-recovery');
      }
    },
  );
}

class _DeviceStatusSource implements RescueStatusSource {
  int calls = 0;
  bool conflict = true;
  final List<int> versions = [];

  @override
  Future<RescueCaseDetail> markFound({
    required String accessToken,
    required String caseId,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    calls += 1;
    versions.add(expectedVersion);
    if (conflict) {
      throw const RescueStatusApiException(
        'Version conflict.',
        code: 'RESCUE_011',
        statusCode: 409,
      );
    }
    return sampleCaseDetail(
      caseId: caseId,
      canUpdateStatus: true,
      version: expectedVersion + 1,
    ).copyWith(status: RescueCaseStatus.found);
  }
}
