import 'package:flutter_test/flutter_test.dart';
import '../../integration_test/day122_closure_capture_sync.dart';

Map<String, Object> sample(int ime) => {
  'physical': [1080.0, 2400.0], 'dpr': 3.0,
  'padding': [0.0, 136.0, 0.0, ime == 0 ? 72.0 : 0.0],
  'view_padding': [0.0, 136.0, 0.0, 72.0],
  'view_insets': [0.0, 0.0, 0.0, ime.toDouble()],
};
void main() {
  test('Chat input checkpoint waits for actual requested keyboard', () async {
    for (final stage in const [
      'chat-quick-reply-draft',
      'chat-quick-reply-sent',
      'chat-composed-message-sent',
    ]) {
      var clock = 0;
      final result = await awaitClosureCaptureMetrics(
        read: () => sample(clock < 600 ? 0 : 909),
        pump: () async {},
        wait: () async { clock += 50; },
        elapsedMs: () => clock,
        expectation: closureImeExpectation('TB-ADOPTION-CHAT'),
        keyboardRequested: closureKeyboardRequested('TB-ADOPTION-CHAT', stage),
      );
      expect((result['view_insets'] as List).last, 909.0, reason: stage);
      expect(clock, greaterThanOrEqualTo(800), reason: stage);
    }
  });
  test('Chat keyboard intent excludes non-input and different journey stages', () {
    for (final stage in const ['shelter-chat', 'adoption-profile',
      'my-adoption-requests', 'chat-back-to-adoption']) {
      expect(closureKeyboardRequested('TB-ADOPTION-CHAT', stage), false);
    }
    expect(closureKeyboardRequested('TB-HEALTH', 'chat-quick-reply-draft'), false);
    expect(closureKeyboardRequested('TB-AUTH', 'chat-quick-reply-draft'), false);
  });
  test('pending requested IME cannot accept a stable zero sample', () async {
    var clock = 0;
    final result = await awaitClosureCaptureMetrics(
      read: () => sample(clock < 600 ? 0 : 909), pump: () async {},
      wait: () async {clock += 50;}, elapsedMs: () => clock,
      expectation: ClosureImeExpectation.stable, keyboardRequested: true,
    );
    expect((result['view_insets'] as List).last, 909.0);
    expect(clock, greaterThanOrEqualTo(800));
  });
  test('requested IME never shown fails within the original deadline', () async {
    var clock = 0;
    await expectLater(awaitClosureCaptureMetrics(
      read: () => sample(0), pump: () async {},
      wait: () async {clock += 50;}, elapsedMs: () => clock,
      expectation: ClosureImeExpectation.stable, keyboardRequested: true,
      deadlineMs: 300,
    ), throwsStateError);
    expect(clock, 300);
  });
  test('keyboard intent belongs only to editor input checkpoints', () {
    expect(closureKeyboardRequested('TB-HEALTH', 'reminder-editor-empty'), true);
    expect(closureKeyboardRequested('TB-HEALTH', 'reminder-api-validation'), true);
    expect(closureKeyboardRequested('TB-HEALTH', 'reminder-saved'), false);
    expect(closureKeyboardRequested('TB-AUTH', 'register-valid-enabled'), false);
  });
  test('must not accept the first IME sample while native transition is pending', () async {
    var clock = 0;
    final result = await awaitClosureCaptureMetrics(
      read: () => sample(clock < 150 ? 909 : 0),
      pump: () async {}, wait: () async { clock += 50; },
      elapsedMs: () => clock, expectation: ClosureImeExpectation.hidden,
    );
    expect(result['view_insets'], [0.0, 0.0, 0.0, 0.0],
      reason: 'must not accept the first IME sample');
    expect(clock, greaterThanOrEqualTo(350));
  });
  test('stable mode preserves a genuinely visible keyboard', () async {
    var clock = 0;
    final result = await awaitClosureCaptureMetrics(
      read: () => sample(909), pump: () async {},
      wait: () async {clock += 50;}, elapsedMs: () => clock,
      expectation: ClosureImeExpectation.stable,
    );
    expect(result['view_insets'], [0.0, 0.0, 0.0, 909.0]);
    expect(clock, 200);
  });
  test('continually changing metrics fail bounded rather than passing late sample', () async {
    var clock = 0;
    await expectLater(awaitClosureCaptureMetrics(
      read: () => sample(clock.isEven ? 900 : 901), pump: () async {},
      wait: () async {clock += 51;}, elapsedMs: () => clock,
      expectation: ClosureImeExpectation.stable, deadlineMs: 300,
    ), throwsStateError);
    expect(clock, lessThan(400));
  });
  test('hidden expectation cannot accept stable visible IME', () async {
    var clock = 0;
    await expectLater(awaitClosureCaptureMetrics(
      read: () => sample(909), pump: () async {},
      wait: () async {clock += 50;}, elapsedMs: () => clock,
      expectation: ClosureImeExpectation.hidden, deadlineMs: 300,
    ), throwsStateError);
  });
  test('malformed or negative inset sample fails closed', () async {
    for(final insets in [<double>[], [0.0,0.0,0.0,-1.0]]) {
      await expectLater(awaitClosureCaptureMetrics(
        read: () => {...sample(0),'view_insets':insets},
        pump: () async {},wait: () async {},elapsedMs: () => 0,
        expectation: ClosureImeExpectation.hidden,
      ),throwsStateError);
    }
  });
  test('only Auth base/form captures intentionally dismiss keyboard', () {
    expect(closureImeExpectation('TB-AUTH'),ClosureImeExpectation.hidden);
    expect(closureImeExpectation('TB-ADOPTION-CHAT'),ClosureImeExpectation.stable);
  });
}
