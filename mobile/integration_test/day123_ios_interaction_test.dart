// Day 123 QA-only iOS interaction probe: edge-swipe back, software keyboard
// and adaptive sheet/picker. Offline fixtures, no auth, no submission.
// Findings are recorded in reportData, not thrown (Day 123 is a TEST day).
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_adaptive.dart';
import 'package:pawmate_mobile/features/auth/presentation/register_screen.dart';
import 'package:pawmate_mobile/features/vets/application/vet_providers.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_detail_screen.dart';

const _launcherTitle = 'D123_LAUNCHER';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  const device = String.fromEnvironment('D123_DEVICE', defaultValue: 'ios');
  final rows = <Map<String, dynamic>>[];
  binding.reportData = {'day': 123, 'device': device, 'rows': rows};

  setUpAll(() {
    if (!Platform.isIOS) throw StateError('Day 123 probe runs on iOS only');
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> settle(WidgetTester t, [int ms = 900]) async {
    await t.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await t.pump();
  }

  Future<void> shot(String id) => binding.takeScreenshot('D123-$device-ix-$id');

  testWidgets('D123 $device edge swipe back from vet detail', (t) async {
    await t.pumpWidget(_app());
    await settle(t);
    await t.tap(find.text('QA_OPEN_VET'));
    await settle(t, 1200);
    final opened = find.byType(VetDetailScreen).evaluate().isNotEmpty;
    final size = t.view.physicalSize / t.view.devicePixelRatio;
    await t.timedDragFrom(
      Offset(4, size.height / 2),
      Offset(size.width * 0.8, 0),
      const Duration(milliseconds: 350),
    );
    await settle(t, 1200);
    final back =
        find.text(_launcherTitle).evaluate().isNotEmpty &&
        find.byType(VetDetailScreen).evaluate().isEmpty;
    await shot('swipe-back');
    rows.add({
      'id': '$device-swipe-back',
      'detail_opened': opened,
      'returned_to_launcher': back,
      'verdict': opened && back ? 'PASS' : 'FINDING',
    });
  });

  testWidgets('D123 $device software keyboard keeps field visible', (t) async {
    await t.pumpWidget(_app());
    await settle(t);
    await t.tap(find.text('QA_OPEN_REGISTER'));
    await settle(t, 1200);
    final fields = find.byType(EditableText);
    final target = fields.evaluate().length > 1 ? fields.at(1) : fields.first;
    await t.ensureVisible(target);
    await t.tap(target);
    await settle(t, 1500);
    final dpr = t.view.devicePixelRatio;
    final inset = t.view.viewInsets.bottom / dpr;
    final height = t.view.physicalSize.height / dpr;
    final rect = t.getRect(target);
    await shot('keyboard');
    final visible = rect.bottom <= height - inset + 1;
    rows.add({
      'id': '$device-keyboard',
      'keyboard_inset': inset,
      'field_bottom': rect.bottom,
      'visible_area_bottom': height - inset,
      'verdict': inset > 0 && visible
          ? 'PASS'
          : inset == 0
          ? 'BLOCKED_NO_SOFTWARE_KEYBOARD'
          : 'FINDING',
    });
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t);
  });

  testWidgets('D123 $device adaptive date picker and action sheet', (t) async {
    await t.pumpWidget(_app());
    await settle(t);
    final height = t.view.physicalSize.height / t.view.devicePixelRatio;

    await t.tap(find.text('QA_OPEN_PICKER'));
    await settle(t, 1200);
    final picker = find.byType(CupertinoDatePicker);
    final pickerShown = picker.evaluate().isNotEmpty;
    final pickerInside = pickerShown && t.getRect(picker).bottom <= height + 1;
    await shot('date-picker');
    await t.tap(find.text('Hủy'));
    await settle(t);
    final pickerClosed = picker.evaluate().isEmpty;

    await t.tap(find.text('QA_OPEN_SHEET'));
    await settle(t, 1200);
    final sheet = find.byType(CupertinoActionSheet);
    final sheetShown = sheet.evaluate().isNotEmpty;
    final sheetInside = sheetShown && t.getRect(sheet).bottom <= height + 1;
    await shot('action-sheet');
    await t.tap(find.text('Hủy'));
    await settle(t);
    final sheetClosed = sheet.evaluate().isEmpty;

    final ok =
        pickerShown &&
        pickerInside &&
        pickerClosed &&
        sheetShown &&
        sheetInside &&
        sheetClosed;
    rows.add({
      'id': '$device-sheet-picker',
      'cupertino_picker': pickerShown,
      'picker_inside_screen': pickerInside,
      'picker_dismissed': pickerClosed,
      'cupertino_action_sheet': sheetShown,
      'sheet_inside_screen': sheetInside,
      'sheet_dismissed': sheetClosed,
      'verdict': ok ? 'PASS' : 'FINDING',
    });
  });
}

Widget _app() => ProviderScope(
  overrides: [
    vetDetailProvider(_clinic.id).overrideWith((ref) async => _clinic),
    vetReviewListProvider(_clinic.id).overrideWith((ref) async => _reviews),
  ],
  child: MaterialApp.router(
    theme: AppTheme.light(),
    locale: const Locale('vi', 'VN'),
    supportedLocales: const [Locale('vi', 'VN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const _Launcher()),
        GoRoute(
          path: '/auth/register',
          builder: (_, _) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/vets/:vetId',
          builder: (_, state) =>
              VetDetailScreen(vetId: state.pathParameters['vetId']!),
        ),
      ],
    ),
  ),
);

class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(_launcherTitle)),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: () => context.push('/vets/${_clinic.id}'),
            child: const Text('QA_OPEN_VET'),
          ),
          FilledButton(
            onPressed: () => context.push('/auth/register'),
            child: const Text('QA_OPEN_REGISTER'),
          ),
          FilledButton(
            onPressed: () => showPawMateAdaptiveDatePicker(
              context: context,
              initialDate: DateTime(2026, 11, 23),
              firstDate: DateTime(2026),
              lastDate: DateTime(2027, 12, 31),
            ),
            child: const Text('QA_OPEN_PICKER'),
          ),
          FilledButton(
            onPressed: () => showPawMateAdaptiveActionSheet<String>(
              context: context,
              title: 'D123 sheet',
              actions: const [PawMateAdaptiveAction(label: 'Chia sẻ')],
            ),
            child: const Text('QA_OPEN_SHEET'),
          ),
        ],
      ),
    ),
  );
}

const _clinic = VetDetail(
  id: 'pethome-q7',
  name: 'PetHome Q7',
  city: 'TP Hồ Chí Minh',
  district: 'Phú Mỹ, Quận 7',
  address: '120 Nguyễn Lương Bằng',
  phone: '',
  summary: 'Cấp cứu 24/7 và chăm sóc định kỳ cho thú cưng.',
  services: ['Tiêm phòng', 'Cấp cứu 24/7', 'Khám tổng quát'],
  seedRank: 1,
  averageRating: 4.8,
  reviewCount: 120,
  is24h: false,
  isOpen: true,
  readyForMap: true,
  latitude: 10.778,
  longitude: 106.701,
  openHours: ['08:00 - 21:00'],
  photoUrls: [],
  source: VetSource(
    url: 'https://pawmate.test',
    list: 'PawMate seeded clinic',
    priorityTier: 'P0',
    enrichmentStatus: 'verified',
    selectionReason: 'day123-ios-interaction',
  ),
);

const _reviews = VetReviewResult(
  items: [],
  summary: VetReviewSummary(
    averageRating: 4.8,
    reviewCount: 120,
    distribution: {},
  ),
  total: 120,
  limit: 20,
);
