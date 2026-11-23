import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_navigation.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_ui.dart';
import '../../pets/application/pet_list_provider.dart';
import '../../pets/data/pet_api.dart';
import '../../pets/domain/pet_profile.dart';
import '../../vets/application/vet_finder_session_provider.dart';
import '../application/health_knowledge_provider.dart';
import '../domain/health_knowledge.dart';

class HealthHubScreen extends ConsumerWidget {
  const HealthHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petListProvider);
    final backendPets = ref.watch(petBackendListProvider);
    final selectedId = ref.watch(selectedPetIdProvider);
    final pet = _resolvePet(pets, selectedId);
    final filter = ref.watch(healthKnowledgeFilterProvider);
    final articles = ref.watch(filteredHealthKnowledgeProvider);

    return PawMatePageScaffold(
      layoutMode: PawMatePageLayoutMode.fullResponsive,
      topBar: PawMateTopBar(
        title: 'Sức khỏe',
        titleSpacing: AppSpacing.s8,
        leading: IconButton(
          tooltip: 'Quay lại',
          color: AppColors.textPrimary,
          onPressed: () => PawMateNavigation.backOrGo(context, '/health'),
          icon: const BackButtonIcon(),
        ),
        actions: [
          _PetQuickAddAction(onPressed: () => context.push('/pets/create')),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s16),
            child: IconButton(
              tooltip: 'Cài đặt thông báo',
              onPressed: () => context.push('/profile/notifications'),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ),
        ],
      ),
      bottomNavCurrentRoute: '/health',
      body: ListView(
        key: const Key('health-hub-scroll'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s16,
          AppSpacing.s16,
          AppSpacing.s32,
        ),
        children: [
          if (pet == null && backendPets.isLoading)
            const _PetSummaryLoading()
          else if (pet == null && backendPets.hasError)
            PawMateStateView(
              key: const Key('health-hub-pet-error'),
              type:
                  backendPets.error is PetApiException &&
                      (backendPets.error! as PetApiException).code ==
                          'NETWORK_ERROR'
                  ? PawMateStateType.offline
                  : PawMateStateType.error,
              title: 'Chưa tải được hồ sơ thú cưng',
              message:
                  '${backendPets.error is PetApiException ? (backendPets.error! as PetApiException).message : 'Hãy kiểm tra kết nối rồi thử lại.'} Hướng dẫn đã lưu bên dưới vẫn dùng được.',
              primaryActionLabel: 'Thử lại',
              onPrimaryAction: () => ref.invalidate(petBackendListProvider),
            )
          else
            _PetHealthSummary(pet: pet),
          const SizedBox(height: AppSpacing.s24),
          const _SectionTitle(title: 'Công cụ & Tiện ích'),
          const SizedBox(height: 20),
          _HealthToolGrid(
            onTimeline: () => context.go('/health'),
            onVaccination: () => context.go('/health'),
            onMedication: () => context.push('/health/reminders'),
            onCondition: () => context.go('/health'),
          ),
          const SizedBox(height: AppSpacing.s24),
          _SectionTitle(
            title: 'Lịch nhắc quan trọng',
            actionLabel: 'Tất cả',
            onAction: () => context.push('/health/reminders'),
          ),
          const SizedBox(height: AppSpacing.s12),
          _ReminderPreview(onTap: () => context.push('/health/reminders')),
          const SizedBox(height: AppSpacing.s24),
          const _SectionTitle(title: 'Hướng dẫn & Kiến thức'),
          const SizedBox(height: AppSpacing.s12),
          _KnowledgeFilters(
            selected: filter,
            onSelected: ref.read(healthKnowledgeFilterProvider.notifier).select,
          ),
          const SizedBox(height: AppSpacing.s12),
          ...articles.map(
            (article) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: _KnowledgeCard(article: article),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          _EmergencyCard(
            onPressed: () {
              ref
                  .read(vetFinderSessionProvider.notifier)
                  .activateEmergencySearch();
              context.go('/vets/map?source=health-emergency');
            },
          ),
        ],
      ),
    );
  }

  PetProfile? _resolvePet(List<PetProfile> pets, String? selectedId) {
    if (pets.isEmpty) return null;
    return pets.firstWhere(
      (pet) => pet.id == selectedId,
      orElse: () => pets.first,
    );
  }
}

class _PetSummaryLoading extends StatelessWidget {
  const _PetSummaryLoading();

  @override
  Widget build(BuildContext context) => Semantics(
    key: const Key('health-hub-pet-loading'),
    label: 'Đang tải hồ sơ sức khỏe thú cưng',
    liveRegion: true,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 202),
      child: const PawMateCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PawMateSkeleton(width: 160, height: 28),
            SizedBox(height: AppSpacing.s16),
            PawMateSkeleton(width: 200, height: 20),
            SizedBox(height: AppSpacing.s24),
            PawMateSkeleton(width: double.infinity, height: 56),
          ],
        ),
      ),
    ),
  );
}

class _PetHealthSummary extends StatelessWidget {
  const _PetHealthSummary({required this.pet});

  final PetProfile? pet;

  @override
  Widget build(BuildContext context) {
    if (pet == null) {
      return PawMateCard(
        child: Column(
          key: const Key('health-hub-empty-pet'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.pets_rounded, color: AppColors.primary500),
            const SizedBox(height: AppSpacing.s16),
            Text('Chưa có hồ sơ thú cưng', style: AppTextStyles.h3()),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Thêm hồ sơ đầu tiên để cá nhân hóa lịch chăm sóc của bé.',
              style: AppTextStyles.bodyCompact(),
            ),
            const SizedBox(height: AppSpacing.s16),
            PawMateButton(
              label: 'Thêm hồ sơ thú cưng',
              leadingIcon: Icons.add,
              onPressed: () => context.push('/pets/create'),
            ),
          ],
        ),
      );
    }
    final name = pet?.name ?? 'Sổ sức khỏe';
    final breed = pet?.breed.trim();
    final description = pet == null
        ? 'Thêm thú cưng để cá nhân hóa lịch chăm sóc.'
        : '${breed?.isNotEmpty == true ? breed : 'Thú cưng'}'
              '${pet?.weightKg == null ? '' : ' • ${pet!.weightKg!.toStringAsFixed(1)} kg'}';
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 202),
      child: PawMateCard(
        variant: PawMateCardVariant.raised,
        padding: const EdgeInsets.fromLTRB(
          20,
          AppSpacing.s16,
          20,
          AppSpacing.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked =
                              constraints.maxWidth < 220 ||
                              MediaQuery.textScalerOf(context).scale(1) > 1.3;
                          final title = Text(
                            name,
                            maxLines: stacked ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.h3(),
                          );
                          const status = PawMateStatus(
                            label: 'Tình trạng sức khỏe',
                            value: PawMateStatusValue.success,
                            text: 'Khỏe mạnh',
                          );
                          if (stacked) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                title,
                                const SizedBox(height: AppSpacing.s8),
                                status,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Flexible(fit: FlexFit.loose, child: title),
                              const SizedBox(width: AppSpacing.s8),
                              status,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(description, style: AppTextStyles.caption()),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.primary500,
                    size: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            LayoutBuilder(
              builder: (context, constraints) {
                final weight = _Metric(
                  icon: Icons.monitor_weight_outlined,
                  label: 'Cân nặng',
                  value: pet?.weightKg == null
                      ? 'Chưa có'
                      : '${pet!.weightKg!.toStringAsFixed(1)} kg',
                );
                const latest = _Metric(
                  icon: Icons.event_available_outlined,
                  label: 'Khám gần nhất',
                  value: 'Xem timeline',
                );
                if (MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
                    constraints.maxWidth < 280) {
                  return Column(
                    children: [
                      weight,
                      const SizedBox(height: AppSpacing.s12),
                      latest,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: weight),
                    const SizedBox(width: AppSpacing.s12),
                    const Expanded(child: latest),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textMuted),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(value, style: AppTextStyles.captionStrong()),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTextStyles.h4())),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _HealthToolGrid extends StatelessWidget {
  const _HealthToolGrid({
    required this.onTimeline,
    required this.onVaccination,
    required this.onMedication,
    required this.onCondition,
  });

  final VoidCallback onTimeline;
  final VoidCallback onVaccination;
  final VoidCallback onMedication;
  final VoidCallback onCondition;

  @override
  Widget build(BuildContext context) {
    final tools = [
      ('Timeline', 'Lịch sử y tế', Icons.timeline_rounded, onTimeline),
      ('Tiêm chủng', 'Sổ tiêm online', Icons.vaccines_outlined, onVaccination),
      ('Uống thuốc', 'Nhắc nhở uống', Icons.medication_outlined, onMedication),
      (
        'Thể trạng',
        'Theo dõi cân nặng',
        Icons.monitor_heart_outlined,
        onCondition,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final twoColumns = constraints.maxWidth >= 340 && textScale <= 1.3;
        final width = twoColumns
            ? (constraints.maxWidth - AppSpacing.s12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: AppSpacing.s12,
          runSpacing: AppSpacing.s12,
          children: tools
              .map(
                (tool) => SizedBox(
                  width: width,
                  child: _HealthToolCard(
                    title: tool.$1,
                    subtitle: tool.$2,
                    icon: tool.$3,
                    onTap: tool.$4,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _HealthToolCard extends StatelessWidget {
  const _HealthToolCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PawMateCard(
      onTap: onTap,
      semanticLabel: '$title, $subtitle',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.centerLeft,
            child: Icon(icon, color: AppColors.primary500, size: 24),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(title, style: AppTextStyles.label()),
          Text(subtitle, style: AppTextStyles.caption()),
        ],
      ),
    );
  }
}

class _PetQuickAddAction extends StatelessWidget {
  const _PetQuickAddAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 72,
    height: AppControlSize.minTouchTarget,
    child: Semantics(
      button: true,
      label: 'Thêm thú cưng',
      child: InkWell(
        key: const Key('health-hub-add-pet'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: AppSpacing.s4,
              child: Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary700),
                ),
                child: const ClipOval(
                  child: Image(
                    image: AssetImage(
                      'assets/images/pets/home_adoption_golden.png',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Positioned(
              right: AppSpacing.s4,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary700),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 22,
                  color: AppColors.primary700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReminderPreview extends StatelessWidget {
  const _ReminderPreview({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PawMateCard(
      onTap: onTap,
      semanticLabel: 'Mở lịch nhắc sức khỏe',
      child: Row(
        children: [
          Container(
            width: 48,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.calendar_month_outlined,
              color: AppColors.primary500,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lịch chăm sóc sắp tới', style: AppTextStyles.label()),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'Xem tiêm phòng, tẩy giun và lịch tái khám',
                  style: AppTextStyles.caption(),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _KnowledgeFilters extends StatelessWidget {
  const _KnowledgeFilters({required this.selected, required this.onSelected});

  final HealthKnowledgeFilter selected;
  final ValueChanged<HealthKnowledgeFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: HealthKnowledgeFilter.values
            .map(
              (filter) => Padding(
                padding: const EdgeInsets.only(right: AppSpacing.s8),
                child: FilterChip(
                  label: Text(filter.label),
                  selected: selected == filter,
                  onSelected: (_) => onSelected(filter),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _KnowledgeCard extends StatelessWidget {
  const _KnowledgeCard({required this.article});

  final HealthKnowledgeArticle article;

  @override
  Widget build(BuildContext context) {
    return PawMateCard(
      semanticLabel: '${article.eyebrow}. ${article.title}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Icon(article.icon, size: 30, color: AppColors.primary500),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.eyebrow,
                  style: AppTextStyles.overline(color: AppColors.primary500),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(article.title, style: AppTextStyles.label()),
                const SizedBox(height: AppSpacing.s4),
                Text(article.summary, style: AppTextStyles.caption()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Trợ giúp khẩn cấp. Tìm phòng khám thú y đang mở gần bạn.',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s24),
        decoration: BoxDecoration(
          color: AppColors.primary500,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.raised,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Text(
                'Trợ giúp khẩn cấp',
                style: AppTextStyles.h3(color: AppColors.white),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            ExcludeSemantics(
              child: Text(
                'Tìm phòng khám thú y đang mở gần bạn.',
                style: AppTextStyles.body(color: AppColors.white),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            PawMateButton(
              key: const Key('health-hub-emergency-vet'),
              label: 'Tìm bác sĩ ngay',
              semanticLabel: 'Tìm bác sĩ thú y đang mở gần bạn',
              onPressed: onPressed,
              variant: PawMateButtonVariant.secondary,
              leadingIcon: Icons.local_hospital_outlined,
              fullWidth: false,
            ),
          ],
        ),
      ),
    );
  }
}
