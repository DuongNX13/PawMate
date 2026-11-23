import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/day122_passive_binding.dart';

void main() {
  final binding = LiveTestWidgetsFlutterBinding();
  testWidgets('Passive binding forwards device-source events, not widget taps',
      (tester) async {
    final prior = binding.shouldPropagateDevicePointerEvents;
    final policy = binding.framePolicy;
    try {
      configureDay122PassiveBinding(binding);
      var count = 0;
      await tester.pumpWidget(MaterialApp(home: Center(child: GestureDetector(
        onTap: () => count++, child: const Text('Device source target'),
      ))));
      final position = tester.getCenter(find.text('Device source target'));
      // Controlled local device-source simulation only, NOT Android/TalkBack.
      binding.handlePointerEventForSource(PointerDownEvent(position: position));
      binding.handlePointerEventForSource(PointerUpEvent(position: position));
      await tester.pump();
      expect(count, 1, reason: 'A passive entry must not silently drop device input');
    } finally {
      binding.shouldPropagateDevicePointerEvents = prior;
      binding.framePolicy = policy;
    }
  });
}
