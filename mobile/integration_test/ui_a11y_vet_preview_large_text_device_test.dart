import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_preview_sheet.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('P1-10 preview sheet remains reachable on Android at text scale 2', (
    tester,
  ) async {
    await binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => binding.setSurfaceSize(null));

    const clinicName = 'Bệnh viện thú y chăm sóc thú cưng chuyên sâu Sài Gòn';
    const clinicAddress =
        '123 Đường Nguyễn Văn Linh, Phường Tân Phong, Quận 7, Thành phố Hồ Chí Minh';
    var directionsTapped = false;
    var callTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (context) => VetPreviewSheet(
                    vet: const VetSummary(
                      id: 'vet-preview-long',
                      name: clinicName,
                      city: 'Thành phố Hồ Chí Minh',
                      district: 'Quận 7',
                      address: clinicAddress,
                      phone: '0903111222',
                      services: [
                        'Khám, chẩn đoán hình ảnh, điều trị nội trú và cấp cứu thú cưng 24 giờ',
                      ],
                      seedRank: 1,
                      averageRating: 4.9,
                      reviewCount: 124,
                      is24h: true,
                      isOpen: true,
                      readyForMap: true,
                    ),
                    onViewDetail: () {},
                    onGetDirections: () => directionsTapped = true,
                    onCallNow: () => callTapped = true,
                  ),
                ),
                child: const Text('Mở xem nhanh'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở xem nhanh'));
    await tester.pumpAndSettle();

    for (final text in [clinicName, clinicAddress]) {
      final finder = find.text(text);
      expect(finder, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(finder).didExceedMaxLines,
        isFalse,
        reason: 'Visible preview-sheet copy must not ellipsize: $text',
      );
    }

    await tester.scrollUntilVisible(find.bySemanticsLabel('Chỉ đường'), 240);
    final directionsButton = find.bySemanticsLabel('Chỉ đường');
    final callButton = find.bySemanticsLabel('Gọi ngay');
    expect(tester.getSize(directionsButton).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(callButton).height, greaterThanOrEqualTo(48));
    await tester.tap(directionsButton);
    await tester.tap(callButton);
    expect(directionsTapped, isTrue);
    expect(callTapped, isTrue);
    expect(tester.takeException(), isNull);
  });
}
