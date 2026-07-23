import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_bottom_nav.dart';
import '../../../core/widgets/pawmate_chip.dart';
import '../application/health_record_providers.dart';
import '../data/health_record_api.dart';
import '../domain/health_record.dart';
import '../../pets/application/pet_list_provider.dart';
import '../../pets/domain/pet_profile.dart';
import '../../reminders/application/reminder_providers.dart';
import '../../reminders/data/reminder_api.dart';
import '../../reminders/domain/reminder.dart';

class HealthTimelineScreen extends ConsumerStatefulWidget {
  const HealthTimelineScreen({super.key});

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
    final useCompactFab =
        MediaQuery.sizeOf(context).width < 430 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.15;

    return Scaffold(
      bottomNavigationBar: const PawMateBottomNav(currentRoute: '/health'),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: useCompactFab
          ? FloatingActionButton(
              heroTag: 'health-add-event-fab',
              tooltip: 'Thêm sự kiện',
              backgroundColor: AppColors.primary500,
              foregroundColor: Colors.white,
              onPressed: selectedPet == null
                  ? null
                  : () => _openAddEventScreen(selectedPet.id),
              child: const Icon(Icons.add_rounded),
            )
          : FloatingActionButton.extended(
              heroTag: 'health-add-event-fab',
              onPressed: selectedPet == null
                  ? null
                  : () => _openAddEventScreen(selectedPet.id),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm sự kiện'),
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 190),
          children: [
            _HealthProfileHeader(
              selectedPet: selectedPet,
              pets: pets,
              selectedPetId: selectedPetId,
              onPetChanged: (value) => setState(() => _selectedPetId = value),
              onSettings: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cài đặt sức khỏe sẽ nối ở bước sau.'),
                ),
              ),
              onNotifications: () =>
                  context.go('/notifications?returnTo=%2Fhealth'),
            ),
            const SizedBox(height: 34),
            Text('Sức khỏe', style: AppTextStyles.pageTitle()),
            const SizedBox(height: 28),
            _ReminderHeroCard(
              reminder: primaryReminder,
              isLoading: upcomingRemindersState.isLoading,
              errorMessage: reminderErrorMessage,
              onTap: () => context.push('/health/reminders'),
            ),
            const SizedBox(height: 28),
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
            const SizedBox(height: 30),
            if (recordQuery == null || recordsState == null)
              _EmptyTimeline(onAdd: () => _openAddEventScreen(selectedPetId))
            else
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
        padding: const EdgeInsets.fromLTRB(66, 0, 0, 14),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: AppColors.primary700,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _formatTimelineGroupDate(date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary700,
                  fontWeight: FontWeight.w700,
                ),
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
    final theme = Theme.of(context);
    final pet = selectedPet;
    final petName = pet?.name ?? 'Chưa có thú cưng';

    return Row(
      children: [
        PopupMenuButton<String>(
          tooltip: 'Chọn thú cưng',
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
          child: _PetAvatar(name: petName, size: 58),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                petName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.04,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _healthStatusLabel(pet),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Cài đặt sức khỏe',
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined, size: 30),
          color: AppColors.textPrimary,
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Thông báo',
          onPressed: onNotifications,
          icon: const Icon(Icons.notifications_none_rounded, size: 30),
          color: AppColors.primary700,
        ),
      ],
    );
  }
}

class _PetAvatar extends StatelessWidget {
  const _PetAvatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(color: AppColors.primary500, width: 3),
      ),
      child: CircleAvatar(
        backgroundColor: AppColors.secondarySoft,
        child: Text(
          name.characters.first.toUpperCase(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.primary700,
            fontWeight: FontWeight.w700,
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
    required this.onTap,
  });

  final Reminder? reminder;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width <= 360;
    final title = isLoading
        ? 'Đang tải lịch nhắc...'
        : errorMessage != null
        ? 'Chưa tải được lịch nhắc'
        : reminder == null
        ? 'Chưa có lịch nhắc sắp tới'
        : '${reminder!.title} - ${_formatReminderHeroTime(reminder!.dueAt)}';

    return Material(
      color: AppColors.primary500,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : 20,
            22,
            compact ? 14 : 20,
            22,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 52 : 62,
                height: compact ? 52 : 62,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  Icons.alarm_rounded,
                  color: Colors.white,
                  size: compact ? 28 : 32,
                ),
              ),
              SizedBox(width: compact ? 12 : 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NHẮC NHỞ SẮP TỚI',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: compact
                          ? AppTextStyles.captionStrong(color: Colors.white)
                          : theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: compact
                          ? AppTextStyles.h3(color: Colors.white)
                          : theme.textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              height: 1.12,
                            ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 6 : 12),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: compact ? 28 : 34,
              ),
            ],
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
    final theme = Theme.of(context);
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
      padding: const EdgeInsets.only(bottom: 26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Column(
              children: [
                _TimelineIcon(type: event.type),
                Container(
                  width: 2,
                  height: 82,
                  margin: const EdgeInsets.only(top: 8),
                  color: AppColors.border.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
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
                  const SizedBox(height: 12),
                  if (event.displayNote.trim().isNotEmpty)
                    Text(
                      event.displayNote,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  const SizedBox(height: 16),
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
                          style: compact
                              ? AppTextStyles.bodyStrong(color: AppColors.label)
                              : theme.textTheme.titleLarge?.copyWith(
                                  color: AppColors.label,
                                  fontWeight: FontWeight.w700,
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
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.16),
        boxShadow: AppShadows.soft,
      ),
      child: Icon(type.icon, color: color, size: 26),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.secondary500,
          fontWeight: FontWeight.w700,
        ),
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
    return Container(
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
              if (showProgress) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
              ],
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
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline({required this.onAdd});

  final VoidCallback onAdd;

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
            'Chưa có sự kiện',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Thêm lần tiêm phòng, tẩy giun hoặc khám bệnh đầu tiên.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm sự kiện'),
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

String _formatReminderHeroTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final now = DateTime.now();
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
