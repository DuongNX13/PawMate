import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_text_field.dart';

void main() {
  for (final native in [true, false]) {
    for (final supports in [null, false, true]) {
      testWidgets('diagnostic native=$native supports=$supports', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    final data = MediaQuery.of(context);
                    debugPrint(
                      'ACTUAL supportsAnnounce=${supports ?? data.supportsAnnounce}',
                    );
                    return MediaQuery(
                      data: data.copyWith(supportsAnnounce: supports),
                      child: native
                          ? const TextFormFieldForDiagnostic()
                          : const PawMateTextField(
                              label: 'Tên',
                              errorText: 'Lỗi thử nghiệm',
                            ),
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final node = tester.getSemantics(find.text('Lỗi thử nghiệm'));
          final context = tester.element(find.byType(TextFormField));
          final actual = MediaQuery.supportsAnnounceOf(context);
          expect(node.label, 'Lỗi thử nghiệm');
          expect(node.getSemanticsData().flagsCollection.isLiveRegion, !actual);
          debugPrint(node.parent?.toStringDeep());
        } finally {
          handle.dispose();
        }
      });
    }
  }
}

class TextFormFieldForDiagnostic extends StatelessWidget {
  const TextFormFieldForDiagnostic({super.key});
  @override
  Widget build(BuildContext context) => TextFormField(
    decoration: const InputDecoration(
      labelText: 'Tên',
      errorText: 'Lỗi thử nghiệm',
    ),
  );
}
