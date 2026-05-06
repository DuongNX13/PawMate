import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/pawmate_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('boots PawMate onboarding shell on a real device target', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: PawMateApp()));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('PawMate'), findsOneWidget);
    expect(find.text('Bắt đầu'), findsOneWidget);
  });
}
