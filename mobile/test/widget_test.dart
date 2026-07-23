import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawmate_mobile/app/pawmate_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders onboarding flow shell', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: PawMateApp()));
    await tester.pumpAndSettle();

    expect(find.text('Hãy cùng làm quen với bạn thân của bạn'), findsOneWidget);
    expect(find.text('TÊN THÚ CƯNG'), findsOneWidget);
    expect(find.text('GIỐNG'), findsOneWidget);
    expect(find.text('TUỔI (NĂM)'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsOneWidget);
  });

  testWidgets('onboarding continue stores draft and opens register', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: PawMateApp()));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'vd: LuLu'), 'Mochi');
    await tester.enterText(
      find.widgetWithText(TextField, 'vd: Golden'),
      'Golden Retriever',
    );
    await tester.enterText(find.widgetWithText(TextField, 'vd: 2'), '2');
    await tester.ensureVisible(
      find.byKey(const ValueKey('onboarding-continue-button')),
    );
    await tester.tap(find.byKey(const ValueKey('onboarding-continue-button')));
    await tester.pumpAndSettle();

    expect(find.text('Tạo tài khoản'), findsWidgets);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hasSeenOnboarding'), isTrue);
    expect(prefs.getString('onboardingDraftPetName'), 'Mochi');
    expect(prefs.getString('onboardingDraftBreed'), 'Golden Retriever');
    expect(prefs.getString('onboardingDraftAge'), '2');
  });
}
