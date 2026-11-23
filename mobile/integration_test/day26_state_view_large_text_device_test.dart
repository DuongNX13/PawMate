import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/app/theme/pawmate_scroll_behavior.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/data/pet_api.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_list_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders P1-05 offline recovery on Android at text scale 2', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWithValue(
            AsyncValue<List<PetProfile>>.error(
              const PetApiException('offline'),
              StackTrace.empty,
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          scrollBehavior: const PawMateScrollBehavior(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const PetListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pet-list-error-state')), findsOneWidget);
    final retry = find.text('Thử lại');
    await tester.ensureVisible(retry);
    expect(retry, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
