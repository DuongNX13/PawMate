import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawmate_mobile/app/pawmate_app.dart';

void main() {
  testWidgets('renders onboarding flow shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PawMateApp()));

    expect(find.text('Bat dau ngay'), findsOneWidget);
  });
}
