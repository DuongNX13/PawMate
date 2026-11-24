import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_add_fab.dart';
import '../../../core/widgets/pawmate_bottom_nav.dart';
import '../../../core/widgets/pawmate_chip.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../../core/widgets/pawmate_skeleton.dart';
import '../application/health_record_providers.dart';
import '../data/health_record_api.dart';
import '../domain/health_record.dart';
import '../../pets/application/pet_list_provider.dart';
import '../../pets/domain/pet_profile.dart';
import '../../pets/presentation/widgets/pet_avatar_media.dart';
import '../../reminders/application/reminder_providers.dart';
import '../../reminders/data/reminder_api.dart';
import '../../reminders/domain/reminder.dart';

class HealthTimelineScreen extends ConsumerStatefulWidget {
  const HealthTimelineScreen({super.key, this.now});

  /// Injectable clock keeps relative reminder labels deterministic in tests.
  final DateTime Function()? now;

  @override
  ConsumerState<HealthTimelineScreen> createState() =>
      _HealthTimelineScreenState();
}

class _HealthTimelineScreenState extends ConsumerState<HealthTimelineScreen> {
  String? _selectedPetId;
  HealthRecordType? _activeFilter;

  @override
  Widget build(BuildContext context) {
    final cachedPets = ref.watch(petListProvider);
    final syncedPetsState = ref.watch(petBackendListProvider);
    final pets = syncedPetsState.maybeWhen(
      data: (items) => items,
      orElse: () => cachedPets,
    );
    final selectedPet = pets.isEmpty
        ? null
        : pets.firstWhere(
            (pet) => pet.id == (_selectedPetId ?? pets.first.id),
            orElse: () => pets.first,
          );
    final selectedPetId = selectedPet?.id;
    final recordQuery = selectedPetId == null
        ? null
        : HealthRecordListQuery(petId: selectedPetId, type: _activeFilter);
    final recordsState = recordQuery == null
        ? null
        : ref.watch(healthRecordListProvider(recordQuery));
    final upcomingRemindersState = ref.watch(upcomingRemindersProvider);
    final primaryReminder = upcomingRemindersState.maybeWhen(
      data: (items) => items.isEmpty ? null : items.first,
      orElse: () => null,
    );
    final reminderErrorMessage = upcomingRemindersState.maybeWhen(
      error: (error, _) => _reminderErrorMessage(error),
      orElse: () => null,
    );
    return Scaffold(
      bottomNavigationBar: const PawMateBottomNav(currentRoute: '/health'),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: PawMateAddFab(
        heroTag: 'health-add-event-fab',
        tooltip: 'Thêm sự kiện',
        onPressed: selectedPet == null
            ? null
            : () => _openAddEventScreen(selectedPet.id),
      ),
      body: SafeArea(
        child: ListView(
          key: const PageStorageKey('health-timeline-scroll'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 190),
          children: [
            _HealthProfileHeader(
              selectedPet: selectedPet,
              pets: pets,
              selectedPetId: selectedPetId,
              onPetChanged: (value) => setState(() => _selectedPetId = value),
              onSettings: () => context.push('/health/knowledge'),
              onNotifications: () =>
                  context.go('/notifications?returnTo=%2Fhealth'),
            ),
            const SizedBox(height: 14),
            Text('Sức khỏe', style: AppTextStyles.pageTitle()),
            const SizedBox(height: 14),
            _ReminderHeroCard(
              reminder: primaryReminder,
              isLoading: upcomingRemindersState.isLoading,
              errorMessage: reminderErrorMessage,
              now: widget.now?.call() ?? DateTime.now(),
              onTap: () => context.push('/health/reminders'),
            ),
            const SizedBox(height: 20),
            if (syncedPetsState.isLoading) ...[
              const _TimelineStatusCard(
                title: 'Đang tải hồ sơ thú cưng',
                message: 'PawMate đang lấy petId thật từ backend.',
                showProgress: true,
              ),
              const SizedBox(height: 18),
            ] else if (syncedPetsState.hasError && pets.isEmpty) ...[
              _TimelineStatusCard(
                title: 'Chưa tải được hồ sơ thú cưng',
                message: 'Không thể đồng bộ hồ sơ thú cưng từ backend.',
                actionLabel: 'Thử lại',
                onAction: () => ref.invalidate(petBackendListProvider),
              ),
              const SizedBox(height: 18),
            ],
            _FilterRow(
              selected: _activeFilter,
              onSelected: (type) => setState(() {
                _activeFilter = type;
              }),
              onShowAll: () => setState(() => _activeFilter = null),
            ),
            const SizedBox(height: 16),
            if (recordQuery == null || recordsState == null) ...[
              if (!syncedPetsState.isLoading && !syncedPetsState.hasError)
                _EmptyTimeline(
                  isFirstPet: true,
                  onAdd: () => context.push('/pets/create?returnTo=%2Fhealth'),
                ),
            ] else
              ..._buildTimelineCards(recordQuery, recordsState),
          ],
        ),
      ),
    );
  }

  void _openAddEventScreen(String? selectedPetId) {
    final petQuery = selectedPetId == null
        ? ''
        : '?petId=${Uri.encodeComponent(selectedPetId)}';
    context.push('/health/events/new$petQuery');
  }

  List<Widget> _buildTimelineCards(
    HealthRecordListQuery query,
    AsyncValue<HealthRecordListResult> recordsState,
  ) {
    return recordsState.when(
      loading: () => const [
        _TimelineStatusCard(
          title: 'Đang đồng bộ',
          message: 'PawMate đang tải hồ sơ sức khỏe từ backend.',
          showProgress: true,
        ),
      ],
      error: (error, _) => [
        _TimelineStatusCard(
          title: 'Chưa đồng bộ được',
          message: _errorMessage(error),
          actionLabel: 'Thử lại',
          onAction: () => ref.invalidate(healthRecordListProvider(query)),
        ),
      ],
      data: (result) {
        if (result.items.isEmpty) {
          return [
            _EmptyTimeline(onAdd: () => _openAddEventScreen(query.petId)),
          ];
        }

        return _groupTimelineByDate(result.items);
      },
    );
  }

  List<Widget> _groupTimelineByDate(List<HealthRecord> records) {
    final sorted = [...records]
      ..sort((left, right) {
        final occurredCompare = right.occurredAt.compareTo(left.occurredAt);
        return occurredCompare != 0
            ? occurredCompare
            : right.createdAt.compareTo(left.createdAt);
      });
    final widgets = <Widget>[];
    String? activeDateKey;

    for (final event in sorted) {
      final dateKey = _dateKey(event.occurredAt);
      if (dateKey != activeDateKey) {
        if (widgets.isNotEmpty) {
          widgets.add(const SizedBox(height: 4));
        }
        widgets.add(_TimelineDateHeader(date: event.occurredAt));
        activeDateKey = dateKey;
      }
      widgets.add(_HealthEventCard(event: event));
    }

    return widgets;
  }
}

class _TimelineDateHeader extends StatelessWidget {
  const _TimelineDateHeader({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        key: Key('health-timeline-date-${_dateKey(date)}'),
        padding: const EdgeInsets.fromLTRB(58, 0, 0, 10),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 16,
              color: AppColors.primary700,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _formatTimelineGroupDate(date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyStrong(color: AppColors.primary700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthProfileHeader extends StatelessWidget {
  const _HealthProfileHeader({
    required this.selectedPet,
    required this.pets,
    required this.selectedPetId,
    required this.onPetChanged,
    required this.onSettings,
    required this.onNotifications,
  });

  final PetProfile? selectedPet;
  final List<PetProfile> pets;
  final String? selectedPetId;
  final ValueChanged<String?> onPetChanged;
  final VoidCallback onSettings;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final pet = selectedPet;
    final petName = pet?.name ?? 'Chưa có thú cưng';

    return Row(
      children: [
        PopupMenuButton<String>(
          tooltip: 'Chọn thú cưng',
          padding: EdgeInsets.zero,
          enabled: pets.isNotEmpty,
          initialValue: selectedPetId,
          onSelected: onPetChanged,
          itemBuilder: (context) => pets
              .map(
                (item) => PopupMenuItem<String>(
                  value: item.id,
                  child: Text(item.name),
                ),
              )
              .toList(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: _PetAvatar(
                name: petName,
                avatarPath: pet?.avatarPath,
                size: 40,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                petName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.h4(),
              ),
              const SizedBox(height: 2),
              Text(
                _healthStatusLabel(pet),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption(),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Trung tâm sức khỏe',
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined, size: 24),
          color: AppColors.textPrimary,
        ),
        IconButton(
          tooltip: 'Thông báo',
          onPressed: onNotifications,
          icon: const Icon(Icons.notifications_none_rounded, size: 24),
          color: AppColors.primary700,
        ),
      ],
    );
  }
}

class _PetAvatar extends StatelessWidget {
  const _PetAvatar({
    required this.name,
    required this.avatarPath,
    required this.size,
  });

  final String name;
  final String? avatarPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(color: AppColors.primary500, width: 2),
      ),
      child: ClipOval(
        child: PetAvatarMedia(
          source: avatarPath,
          semanticLabel: 'Ảnh của $name',
          fallback: ColoredBox(
            color: AppColors.secondarySoft,
            child: Center(
              child: Text(
                name.characters.first.toUpperCase(),
                style: AppTextStyles.label(color: AppColors.primary700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderHeroCard extends StatelessWidget {
  const _ReminderHeroCard({
    required this.reminder,
    required this.isLoading,
    required this.errorMessage,
    required this.now,
    required this.onTap,
  });

  final Reminder? reminder;
  final bool isLoading;
  final String? errorMessage;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = isLoading
        ? 'Đang tải lịch nhắc...'
        : errorMessage != null
        ? 'Chưa tải được lịch nhắc'
        : reminder == null
        ? 'Chưa có lịch nhắc sắp tới'
        : '${reminder!.title} - ${_formatReminderHeroTime(reminder!.dueAt, now)}';

    return Material(
      key: const Key('health-reminder-hero'),
      color: AppColors.primary500,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.alarm_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NHẮC NHỞ SẮP TỚI',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.captionStrong(color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h4(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selected,
    required this.onSelected,
    required this.onShowAll,
  });

  final HealthRecordType? selected;
  final ValueChanged<HealthRecordType> onSelected;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final filters = [
      _HealthFilterOption(label: 'Vaccine', type: HealthRecordType.vaccination),
      _HealthFilterOption(label: 'Cân nặng', type: HealthRecordType.checkup),
      _HealthFilterOption(label: 'Thuốc', type: HealthRecordType.medication),
      _HealthFilterOption(label: 'Tẩy giun', type: HealthRecordType.deworming),
      _HealthFilterOption(label: 'Dị ứng', type: HealthRecordType.allergy),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _FilterPill(
            label: 'Tất cả',
            selected: selected == null,
            onTap: onShowAll,
          ),
          const SizedBox(width: 12),
          ...filters.map(
            (option) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _FilterPill(
                label: option.label,
                selected: selected == option.type,
                onTap: () => onSelected(option.type),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthFilterOption {
  const _HealthFilterOption({required this.label, required this.type});

  final String label;
  final HealthRecordType type;
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PawMateChip(
      key: ValueKey('health-filter-$label'),
      label: label,
      selected: selected,
      onPressed: onTap,
      semanticLabel: '$label, ${selected ? 'đã chọn' : 'chưa chọn'}',
    );
  }
}

class _HealthEventCard extends StatelessWidget {
  const _HealthEventCard({required this.event});

  final HealthRecord event;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 360;
    final status = event.type == HealthRecordType.vaccination
        ? 'THÀNH CÔNG'
        : null;
    final title = Text(
      event.displayTitle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.cardTitle(),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Column(
              children: [
                _TimelineIcon(type: event.type),
                Container(
                  width: 2,
                  height: 54,
                  margin: const EdgeInsets.only(top: 6),
                  color: AppColors.border.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              key: Key('health-event-${event.id}'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.65),
                ),
                boxShadow: AppShadows.soft,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (compact && status != null) ...[
                    title,
                    const SizedBox(height: 8),
                    _StatusBadge(label: status),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: title),
                        if (status != null) ...[
                          const SizedBox(width: 10),
                          _StatusBadge(label: status),
                        ],
                      ],
                    ),
                  const SizedBox(height: 8),
                  if (event.displayNote.trim().isNotEmpty)
                    Text(
                      event.displayNote,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(color: AppColors.textSecondary),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: AppColors.label,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _formatDateTime(event),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.captionStrong(
                            color: AppColors.label,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (event.vetId != null || event.attachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (event.vetId != null)
                          _MetaPill(
                            icon: Icons.local_hospital_outlined,
                            label: event.vetId!,
                          ),
                        if (event.attachments.isNotEmpty)
                          _MetaPill(
                            icon: Icons.attach_file_rounded,
                            label: '${event.attachments.length} tệp',
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(HealthRecord event) {
    final value = event.occurredAt;
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final time = event.time?.trim();
    return time == null || time.isEmpty
        ? '$day/$month/${value.year}'
        : '$day/$month/${value.year} · $time';
  }
}

class _TimelineIcon extends StatelessWidget {
  const _TimelineIcon({required this.type});

  final HealthRecordType type;

  @override
  Widget build(BuildContext context) {
    final color = type.accentColor;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.16),
        boxShadow: AppShadows.soft,
      ),
      child: Icon(type.icon, color: color, size: 22),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: AppTextStyles.micro(color: AppColors.secondary500),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.secondarySoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.secondary500),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.secondary500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStatusCard extends StatelessWidget {
  const _TimelineStatusCard({
    required this.title,
    required this.message,
    this.showProgress = false,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final bool showProgress;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.secondarySoft,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            if (showProgress) ...[
              const SizedBox(height: 12),
              const PawMateSkeleton(width: double.infinity, height: 18),
              const SizedBox(height: 8),
              const PawMateSkeleton(width: 160, height: 18),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              PawMateButton(
                label: actionLabel!,
                onPressed: onAction,
                fullWidth: false,
                variant: PawMateButtonVariant.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline({required this.onAdd, this.isFirstPet = false});

  final VoidCallback onAdd;
  final bool isFirstPet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.secondarySoft,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFirstPet ? 'Chưa có hồ sơ thú cưng' : 'Chưa có sự kiện',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            isFirstPet
                ? 'Thêm thú cưng đầu tiên để theo dõi sức khỏe và lịch nhắc.'
                : 'Thêm lần tiêm phòng, tẩy giun hoặc khám bệnh đầu tiên.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          PawMateButton(
            onPressed: onAdd,
            leadingIcon: Icons.add_rounded,
            fullWidth: false,
            variant: PawMateButtonVariant.secondary,
            label: isFirstPet ? 'Thêm hồ sơ thú cưng' : 'Thêm sự kiện',
          ),
        ],
      ),
    );
  }
}

extension _HealthRecordTypeStyle on HealthRecordType {
  Color get accentColor {
    switch (this) {
      case HealthRecordType.vaccination:
        return AppColors.brown;
      case HealthRecordType.deworming:
        return AppColors.deepGreen;
      case HealthRecordType.checkup:
        return AppColors.deepGreen;
      case HealthRecordType.grooming:
        return AppColors.brown;
      case HealthRecordType.medication:
        return AppColors.deepGreen;
      case HealthRecordType.allergy:
        return AppColors.error;
      case HealthRecordType.note:
        return AppColors.brown;
    }
  }

  IconData get icon {
    switch (this) {
      case HealthRecordType.vaccination:
        return Icons.vaccines_outlined;
      case HealthRecordType.deworming:
        return Icons.spa_outlined;
      case HealthRecordType.checkup:
        return Icons.monitor_weight_outlined;
      case HealthRecordType.grooming:
        return Icons.content_cut_rounded;
      case HealthRecordType.medication:
        return Icons.medication_outlined;
      case HealthRecordType.allergy:
        return Icons.warning_amber_rounded;
      case HealthRecordType.note:
        return Icons.note_alt_outlined;
    }
  }
}

String _errorMessage(Object error) {
  if (error is HealthRecordApiException) {
    return error.message;
  }
  return 'Không thể đồng bộ hồ sơ sức khỏe. Vui lòng thử lại.';
}

String _reminderErrorMessage(Object error) {
  if (error is ReminderApiException) {
    return error.message;
  }
  return 'Không thể đồng bộ lịch nhắc. Vui lòng thử lại.';
}

String _dateKey(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _formatTimelineGroupDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return 'Ngày $day/$month/${value.year}';
}

String _healthStatusLabel(PetProfile? pet) {
  final status = pet?.healthStatus.trim().toLowerCase();
  switch (status) {
    case 'healthy':
    case 'good':
      return 'Sức khỏe tốt';
    case 'needs_vaccine':
    case 'needs care':
      return 'Cần theo dõi';
    case 'unknown':
    case null:
      return 'Đang cập nhật';
    default:
      return 'Theo dõi sức khỏe';
  }
}

String _formatReminderHeroTime(DateTime value, DateTime now) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(value.year, value.month, value.day);
  final dayDelta = target.difference(today).inDays;
  final dayLabel = switch (dayDelta) {
    0 => 'Hôm nay',
    1 => 'Ngày mai',
    -1 => 'Hôm qua',
    _ =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}',
  };

  return '$dayLabel, $hour:$minute';
}
