import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/pawmate_app.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('onboarding validates required name and age range', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    await tester.pumpWidget(const ProviderScope(child: PawMateApp()));
    await tester.pumpAndSettle();

    await tester.enterText(
      _fieldWithin(const Key('onboarding-age-field')),
      '51',
    );
    await tester.ensureVisible(
      find.byKey(const Key('onboarding-continue-button')),
    );
    await tester.tap(find.byKey(const Key('onboarding-continue-button')));
    await tester.pumpAndSettle();

    expect(find.text('Vui lòng nhập tên thú cưng'), findsOneWidget);
    expect(find.text('Tuổi phải là số từ 0 đến 50'), findsOneWidget);
    expect(find.text('Hãy cùng làm quen với bạn thân của bạn'), findsOneWidget);
    expect(find.text('Tạo tài khoản'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hasSeenOnboarding'), isNot(true));
    expectNoFlutterOverflow(tester);
  });

  testWidgets('onboarding restores local draft and skip opens login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboardingDraftPetName': 'Mochi',
      'onboardingDraftBreed': 'Mèo tam thể',
      'onboardingDraftAge': '2',
    });
    await setTestViewport(tester, size: const Size(390, 844));
    await tester.pumpWidget(const ProviderScope(child: PawMateApp()));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(
            _fieldWithin(const Key('onboarding-pet-name-field')),
          )
          .controller
          ?.text,
      'Mochi',
    );
    expect(
      tester
          .widget<TextFormField>(
            _fieldWithin(const Key('onboarding-breed-field')),
          )
          .controller
          ?.text,
      'Mèo tam thể',
    );
    expect(
      tester
          .widget<TextFormField>(
            _fieldWithin(const Key('onboarding-age-field')),
          )
          .controller
          ?.text,
      '2',
    );

    await tester.ensureVisible(
      find.byKey(const Key('onboarding-login-button')),
    );
    await tester.tap(find.byKey(const Key('onboarding-login-button')));
    await tester.pumpAndSettle();

    expect(find.text('Mừng bạn đã trở lại'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hasSeenOnboarding'), isTrue);
    expect(prefs.getString('onboardingDraftPetName'), 'Mochi');
    expectNoFlutterOverflow(tester);
  });

  testWidgets('onboarding remains usable with enlarged text', (tester) async {
    final semantics = tester.ensureSemantics();
    await setTestViewport(tester, size: const Size(320, 568));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(2),
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hãy cùng làm quen với bạn thân của bạn'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Minh họa chó cưng cho bước thiết lập hồ sơ thú cưng',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('onboarding-progress-rails')), findsNothing);

    final photoPicker = find.byKey(const Key('onboarding-photo-picker'));
    final photoButton = tester.widget<IconButton>(photoPicker);
    expect(photoButton.tooltip, 'Thêm ảnh thú cưng');
    final photoData = tester.getSemantics(photoPicker).getSemanticsData();
    expect(photoData.flagsCollection.isButton, isTrue);
    expect(photoData.hasAction(SemanticsAction.tap), isTrue);
    expect(tester.getSize(photoPicker).shortestSide, greaterThanOrEqualTo(48));

    for (final key in const [
      ValueKey('onboarding-continue-button'),
      ValueKey('onboarding-login-button'),
    ]) {
      final button = find.byKey(key);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expectNoFlutterOverflow(tester);
    }

    expect(find.bySemanticsLabel('Tiếp tục'), findsOneWidget);
    expect(find.bySemanticsLabel('Bỏ qua và đăng nhập'), findsOneWidget);
    expectNoFlutterOverflow(tester);
    semantics.dispose();
  });

  testWidgets('onboarding omits progress rails under a system top inset', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: const EdgeInsets.only(top: 32)),
            child: child!,
          ),
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-progress-rails')), findsNothing);
    expect(
      find.bySemanticsLabel(
        'Minh họa chó cưng cho bước thiết lập hồ sơ thú cưng',
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('onboarding-photo-picker'))).width,
      greaterThanOrEqualTo(48),
    );
    expectNoFlutterOverflow(tester);
  });
}

Finder _fieldWithin(Key key) {
  return find.descendant(
    of: find.byKey(key),
    matching: find.byType(TextFormField),
  );
}
