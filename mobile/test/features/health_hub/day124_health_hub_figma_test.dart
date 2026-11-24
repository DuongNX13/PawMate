import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/health_hub/presentation/health_hub_screen.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';
import 'package:pawmate_mobile/features/reminders/domain/reminder.dart';

import '../../test_support/ui_test_helpers.dart';

// D123-IOS-UI-009: Figma v0.34 P2-13 (590:15688) uses a mint hero card with
// pet avatar, status chip and cream metric tiles, tinted tool tiles and a
// dated reminder card. The health score badge is not shown (no real data).
final _due = DateTime(2026, 11, 25, 9, 30);

Future<void> _pump(
  WidgetTester t, {
  List<Reminder> reminders = const [],
}) async {
  await setTestViewport(t, size: const Size(430, 932));
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        petListProvider.overrideWith(_Pets.new),
        upcomingRemindersProvider.overrideWith((ref) async => reminders),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const HealthHubScreen(),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadPawMateTestFonts);

  testWidgets('hero card is mint with avatar, chip and metric values', (
    t,
  ) async {
    await _pump(t);
    final hero = t.widget<Container>(find.byKey(const Key('health-hub-hero')));
    expect((hero.decoration! as BoxDecoration).color, const Color(0xFFE5F4EA));
    expect(find.byKey(const Key('health-hub-pet-avatar')), findsOneWidget);
    expect(find.text('KHỎE MẠNH'), findsOneWidget);
    expect(find.textContaining('12.4', findRichText: true), findsOneWidget);
    expect(find.textContaining('92'), findsNothing);
    expectNoFlutterOverflow(t);
  });

  testWidgets('tool tiles have filled icon squares', (t) async {
    await _pump(t);
    expect(find.byKey(const Key('health-hub-tool-icon')), findsNWidgets(4));
  });

  testWidgets('reminder card shows the due date block and time', (t) async {
    await _pump(
      t,
      reminders: [
        Reminder(
          id: 'r1',
          petId: 'pet-mochi',
          title: 'Tiêm phòng dại',
          note: 'PetCare Elite Q7',
          reminderAt: _due,
          repeatRule: ReminderRepeatRule.none,
          timezone: 'Asia/Ho_Chi_Minh',
          status: ReminderStatus.scheduled,
          createdAt: '2026-11-24T00:00:00Z',
          updatedAt: '2026-11-24T00:00:00Z',
        ),
      ],
    );
    expect(find.byKey(const Key('health-hub-reminder-date')), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('Tiêm phòng dại'), findsOneWidget);
    expect(find.textContaining('09:30'), findsOneWidget);
  });
}

class _Pets extends PetListNotifier {
  @override
  List<PetProfile> build() => const [
    PetProfile(
      id: 'pet-mochi',
      name: 'Mochi',
      species: 'dog',
      breed: 'Golden Retriever',
      gender: 'female',
      weightKg: 12.4,
      healthStatus: 'healthy',
    ),
  ];
}
