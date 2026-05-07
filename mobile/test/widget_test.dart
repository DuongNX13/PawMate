import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawmate_mobile/app/pawmate_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders onboarding flow shell', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: PawMateApp()));
    await tester.pumpAndSettle();

    expect(find.text('Bắt đầu'), findsOneWidget);
  });
}
