// QA-only, read-only oracle. No gesture, navigation, focus or text mutation.
import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_detail_screen.dart';

import 'day122_closure_journeys.dart';
import 'day122_closure_stages.dart';

const passiveHomeStages = [
  'home-first-pet-selected',
  'second-pet-detail',
  'home-retains-second-pet',
];

void validatePassiveHomeRequest(
  Map<String, dynamic> request, {
  required String run,
  required int nextSequence,
}) {
  if (nextSequence < 1 || nextSequence > passiveHomeStages.length ||
      request['run'] != run || request['sequence'] != nextSequence ||
      request['stage'] != passiveHomeStages[nextSequence - 1] ||
      request.keys.toSet().difference({'run', 'sequence', 'stage'}).isNotEmpty) {
    throw StateError('Wrong run, sequence, stage or unsupported command');
  }
}

Map<String, Object?> observePassiveHome(
  WidgetTester tester,
  ClosureHomePetHarness harness,
  String stage,
) {
  if (!passiveHomeStages.contains(stage)) throw StateError('Unknown stage');
  final expectedPet = stage == passiveHomeStages.first ? 'mochi' : 'bap';
  final selected = harness.container.read(selectedPetIdProvider);
  expect(selected, expectedPet, reason: 'Observe actual selected provider value');
  final result = inspectClosureStage(
    tester, 'TB-HOME-PET', stage, closureViewMetrics(tester.view),
  );
  if (stage == 'second-pet-detail') {
    expect(tester.widget<PetDetailScreen>(find.byType(PetDetailScreen)).petId,
        'bap', reason: 'Route alone cannot prove correct pet');
    expect(find.text('Bắp'), findsOneWidget);
  } else {
    final pet = find.byKey(const Key('home-pet-avatar-bap'));
    expect(pet, findsOneWidget);
    expect(tester.getSemantics(pet).flagsCollection.isSelected,
        stage == passiveHomeStages.first ? Tristate.isFalse : Tristate.isTrue);
  }
  return {
    ...result,
    'proof_scope': 'PASSIVE_QA_STATE_OBSERVATION_NOT_INPUT_PROOF',
    'input_method': 'NONE_OBSERVER_ONLY',
    'talkback_acceptance': false,
    'stage': stage,
    'selected_pet_id': selected,
    'fixture_backend': true,
  };
}
