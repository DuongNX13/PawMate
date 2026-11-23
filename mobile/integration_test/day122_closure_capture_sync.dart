// QA-only native capture synchronization. Never overrides platform metrics.
import 'dart:convert';

enum ClosureImeExpectation { hidden, stable }

ClosureImeExpectation closureImeExpectation(String journey) =>
    journey == 'TB-AUTH'
    ? ClosureImeExpectation.hidden
    : ClosureImeExpectation.stable;

/// Wait for observed values, not a fixed sleep or a synthetic inset override.
/// The injected clock/wait in unit tests are LOCAL mechanism proof only.
Future<Map<String, Object>> awaitClosureCaptureMetrics({
  required Map<String, Object> Function() read,
  required Future<void> Function() pump,
  required Future<void> Function() wait,
  required int Function() elapsedMs,
  required ClosureImeExpectation expectation,
  bool keyboardRequested = false,
  int deadlineMs = 3000,
  int stableMs = 200,
}) async {
  final start = elapsedMs();
  String? previous;
  int? stableSince;
  while (elapsedMs() - start < deadlineMs) {
    await pump();
    final metrics = read();
    // Controlled mutation restores the pre-fix one-sample capture behavior.
    if (const bool.fromEnvironment('D122_MUTATE_CAPTURE_STABILITY')) {
      return metrics;
    }
    final encoded = jsonEncode(metrics);
    final insets = metrics['view_insets'];
    if (insets is! List || insets.length != 4 ||
        insets.any((v) => v is! num || !v.isFinite || v < 0)) {
      throw StateError('Invalid capture inset observation');
    }
    final requireVisible = keyboardRequested &&
        !const bool.fromEnvironment('D122_MUTATE_REQUESTED_VISIBLE');
    final expected = expectation == ClosureImeExpectation.hidden
        ? insets.every((v) => v == 0)
        : !requireVisible || (insets.last as num) > 0;
    final now = elapsedMs();
    if (!expected || previous != encoded) {
      stableSince = expected ? now : null;
    }
    previous = encoded;
    if (expected && stableSince != null && now - stableSince >= stableMs) {
      return metrics;
    }
    await wait();
  }
  throw StateError('Native capture metric stability deadline: ${expectation.name}; last=$previous');
}

// Intent is declared from recipe actions, never inferred from a zero inset.
bool closureKeyboardRequested(String journey, String stage) =>
    (journey == 'TB-HEALTH' &&
        const {'reminder-editor-empty', 'reminder-api-validation'}.contains(stage)) ||
    // The production quick-reply and successful-send actions request composer
    // focus. A stable zero sample may precede Android's asynchronous IME show.
    (journey == 'TB-ADOPTION-CHAT' &&
        const {
          'chat-quick-reply-draft',
          'chat-quick-reply-sent',
          'chat-composed-message-sent',
        }.contains(stage));
