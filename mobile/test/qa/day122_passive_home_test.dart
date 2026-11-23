import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../integration_test/day122_closure_journeys.dart';
import '../../integration_test/day122_passive_home_observer.dart';
import '../test_support/ui_test_helpers.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });
  test('Passive request rejects wrong identity, stale sequence and actions', () {
    final good = <String, dynamic>{'run': 'closure-test', 'sequence': 1,
      'stage': passiveHomeStages.first};
    validatePassiveHomeRequest(good, run: 'closure-test', nextSequence: 1);
    for (final bad in [
      {...good, 'run': 'other'}, {...good, 'sequence': 0},
      {...good, 'stage': 'second-pet-detail'}, {...good, 'tap': 'bap'},
    ]) {
      expect(() => validatePassiveHomeRequest(bad,
          run: 'closure-test', nextSequence: 1), throwsStateError);
    }
  });
  testWidgets('Read-only oracle rejects unperformed action and wrong pet', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
    final harness = await pumpClosureHomePetJourney(tester, const Size(360, 800));
    final first = observePassiveHome(tester, harness, passiveHomeStages.first);
    expect(first['selected_pet_id'], 'mochi');
    expect(first['input_method'], 'NONE_OBSERVER_ONLY');
    expect(() => observePassiveHome(tester, harness, 'second-pet-detail'),
        throwsA(isA<TestFailure>()));
    // Local setup actions below are NOT native/TalkBack proof.
    await tester.tap(find.byKey(const Key('home-pet-avatar-mochi')));
    await tester.pumpAndSettle();
    expect(() => observePassiveHome(tester, harness, 'second-pet-detail'),
        throwsA(isA<TestFailure>()));
    } finally { semantics.dispose(); }
  });
  testWidgets('Oracle reads three actual states without performing actions', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
    final harness = await pumpClosureHomePetJourney(tester, const Size(360, 800));
    observePassiveHome(tester, harness, passiveHomeStages.first);
    await tester.tap(find.byKey(const Key('home-pet-avatar-bap')));
    await tester.pumpAndSettle();
    final detail = observePassiveHome(tester, harness, 'second-pet-detail');
    expect(detail['mounted_route'], '/pets/bap');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final back = observePassiveHome(tester, harness, 'home-retains-second-pet');
    expect(back['selected_pet_id'], 'bap');
    expect(back['talkback_acceptance'], false);
    expectNoFlutterOverflow(tester);
    } finally { semantics.dispose(); }
  });
}
