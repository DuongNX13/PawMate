import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/pawmate_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('launches onboarding for a first-time guest', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: PawMateApp()));
    await tester.pumpAndSettle();

    expect(find.text('Hãy cùng làm quen với bạn thân của bạn'), findsOneWidget);
    expect(find.text('Mừng bạn đã trở lại'), findsNothing);
  });

  testWidgets('launches login after onboarding without an active session', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'hasSeenOnboarding': true,
      'hasActiveSession': false,
    });
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: PawMateApp()));
    await tester.pumpAndSettle();

    expect(find.text('Mừng bạn đã trở lại'), findsOneWidget);
    expect(find.text('Hãy cùng làm quen với bạn thân của bạn'), findsNothing);
  });
}
