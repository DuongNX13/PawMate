import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/health_knowledge.dart';

final healthKnowledgeFilterProvider =
    NotifierProvider<HealthKnowledgeFilterNotifier, HealthKnowledgeFilter>(
      HealthKnowledgeFilterNotifier.new,
    );

final filteredHealthKnowledgeProvider = Provider<List<HealthKnowledgeArticle>>((
  ref,
) {
  final filter = ref.watch(healthKnowledgeFilterProvider);
  if (filter == HealthKnowledgeFilter.all) {
    return bundledHealthKnowledge;
  }
  return bundledHealthKnowledge
      .where((article) => article.filter == filter)
      .toList(growable: false);
});

class HealthKnowledgeFilterNotifier extends Notifier<HealthKnowledgeFilter> {
  @override
  HealthKnowledgeFilter build() => HealthKnowledgeFilter.all;

  void select(HealthKnowledgeFilter value) {
    state = value;
  }
}
