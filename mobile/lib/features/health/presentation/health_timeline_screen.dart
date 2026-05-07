import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_bottom_nav.dart';
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
  final _noteController = TextEditingController();
  final _clinicController = TextEditingController();
  String? _selectedPetId;
  HealthRecordType? _activeFilter;
  HealthRecordType _newEventType = HealthRecordType.vaccination;
  bool _isSavingEvent = false;
  String? _saveError;

  @override
  void dispose() {
    _noteController.dispose();
    _clinicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncedPetsState = ref.watch(petBackendListProvider);
    final pets = syncedPetsState.maybeWhen(
      data: (items) => items,
      orElse: () => const <PetProfile>[],
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

    return Scaffold(
      bottomNavigationBar: const PawMateBottomNav(currentRoute: '/health'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: selectedPet == null ? null : () => _openAddEventSheet(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm sự kiện'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 132),
          children: [
            Text(
              'Sức khỏe',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppColors.primary700,
                fontWeight: FontWeight.w800,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Thông báo',
                onPressed: () => context.go('/notifications'),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Theo dõi tiêm phòng, tẩy giun và lịch nhắc theo từng bé.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
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
            _PetSelectorCard(
              petName: selectedPet?.name ?? 'Chưa có thú cưng',
              subtitle: selectedPet == null
                  ? 'Tạo hồ sơ thú cưng trước khi ghi nhận sức khỏe.'
                  : recordsState?.maybeWhen(
                          data: (result) =>
                              '${selectedPet.breed} · ${result.items.length} sự kiện',
                          loading: () => '${selectedPet.breed} · đang đồng bộ',
                          error: (_, _) =>
                              '${selectedPet.breed} · cần kiểm tra đồng bộ',
                          orElse: () => selectedPet.breed,
                        ) ??
                        selectedPet.breed,
              pets: pets
                  .map(
                    (pet) =>
                        DropdownMenuItem(value: pet.id, child: Text(pet.name)),
                  )
                  .toList(),
              selectedPetId: selectedPetId,
              onChanged: (value) => setState(() => _selectedPetId = value),
            ),
            const SizedBox(height: 18),
            _FilterRow(
              selected: _activeFilter,
              onSelected: (type) => setState(() {
                _activeFilter = _activeFilter == type ? null : type;
              }),
            ),
            const SizedBox(height: 24),
            Text('Timeline', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (recordQuery == null || recordsState == null)
              _EmptyTimeline(onAdd: () => _openAddEventSheet())
            else
              ..._buildTimelineCards(recordQuery, recordsState),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sắp tới',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/health/reminders'),
                  child: const Text('Xem lịch'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._buildUpcomingReminderCards(upcomingRemindersState),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildUpcomingReminderCards(
    AsyncValue<List<Reminder>> remindersState,
  ) {
    return remindersState.when(
      loading: () => const [
        _TimelineStatusCard(
          title: 'Đang tải lịch nhắc',
          message: 'PawMate đang lấy các lịch sắp tới từ backend.',
          showProgress: true,
        ),
      ],
      error: (error, _) => [
        _TimelineStatusCard(
          title: 'Chưa tải được lịch nhắc',
          message: _reminderErrorMessage(error),
          actionLabel: 'Thử lại',
          onAction: () => ref.invalidate(upcomingRemindersProvider),
        ),
      ],
      data: (reminders) {
        if (reminders.isEmpty) {
          return const [
            _TimelineStatusCard(
              title: 'Chưa có lịch nhắc sắp tới',
              message:
                  'Tạo lịch nhắc để PawMate theo dõi ngày tiêm và tái khám.',
            ),
          ];
        }

        return reminders
            .map<Widget>(
              (reminder) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _UpcomingReminderCard(
                  title: reminder.title,
                  subtitle:
                      '${_formatReminderDate(reminder.dueAt)} · ${reminder.repeatRule.label}',
                  accentColor: AppColors.primary500,
                ),
              ),
            )
            .toList();
      },
    );
  }

  void _openAddEventSheet() {
    _noteController.clear();
    _clinicController.clear();
    _newEventType = HealthRecordType.vaccination;
    _isSavingEvent = false;
    _saveError = null;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thêm sự kiện',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<HealthRecordType>(
                    initialValue: _newEventType,
                    decoration: const InputDecoration(
                      labelText: 'Loại sự kiện',
                    ),
                    items: HealthRecordType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => _newEventType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú',
                      hintText: 'Ví dụ: bé ăn uống bình thường sau tiêm',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _clinicController,
                    decoration: const InputDecoration(
                      labelText: 'Mã phòng khám - tùy chọn',
                      hintText: 'Ví dụ: petcare-elite',
                    ),
                  ),
                  if (_saveError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _saveError!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSavingEvent
                          ? null
                          : () => _saveRemoteEvent(sheetContext, setSheetState),
                      child: Text(
                        _isSavingEvent ? 'Đang lưu...' : 'Lưu sự kiện',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
          return [_EmptyTimeline(onAdd: () => _openAddEventSheet())];
        }

        return result.items
            .map<Widget>((event) => _HealthEventCard(event: event))
            .toList();
      },
    );
  }

  Future<void> _saveRemoteEvent(
    BuildContext sheetContext,
    StateSetter setSheetState,
  ) async {
    final List<PetProfile> pets = ref
        .read(petBackendListProvider)
        .maybeWhen(
          data: (items) => items,
          orElse: () => ref.read(petListProvider),
        );
    if (pets.isEmpty) {
      return;
    }

    final petId = _selectedPetId ?? pets.first.id;
    final type = _newEventType;
    setSheetState(() {
      _isSavingEvent = true;
      _saveError = null;
    });

    try {
      final accessToken = await ref.read(
        healthRecordAccessTokenProvider.future,
      );
      if (accessToken == null) {
        throw const HealthRecordApiException(
          'Bạn cần đăng nhập để lưu hồ sơ sức khỏe.',
          code: 'AUTH_REQUIRED',
          statusCode: 401,
        );
      }

      await ref
          .read(healthRecordApiProvider)
          .createRecord(
            petId,
            CreateHealthRecordInput(
              type: type,
              date: DateTime.now(),
              title: type.defaultTitle,
              note: _noteController.text,
              vetId: _clinicController.text,
            ),
            accessToken: accessToken,
          );

      if (!mounted) {
        return;
      }

      setState(() => _activeFilter = null);
      ref.invalidate(
        healthRecordListProvider(HealthRecordListQuery(petId: petId)),
      );
      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setSheetState(() {
        _isSavingEvent = false;
        _saveError = _errorMessage(error);
      });
    }
  }
}

class _PetSelectorCard extends StatelessWidget {
  const _PetSelectorCard({
    required this.petName,
    required this.subtitle,
    required this.pets,
    required this.selectedPetId,
    required this.onChanged,
  });

  final String petName;
  final String subtitle;
  final List<DropdownMenuItem<String>> pets;
  final String? selectedPetId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: Text(
              petName.characters.first.toUpperCase(),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppColors.primary700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(petName, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (pets.isNotEmpty)
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedPetId,
                items: pets,
                onChanged: onChanged,
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onSelected});

  final HealthRecordType? selected;
  final ValueChanged<HealthRecordType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: HealthRecordType.values.map((type) {
        return FilterChip(
          selected: selected == type,
          label: Text(type.label),
          onSelected: (_) => onSelected(type),
        );
      }).toList(),
    );
  }
}

class _HealthEventCard extends StatelessWidget {
  const _HealthEventCard({required this.event});

  final HealthRecord event;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 54,
            decoration: BoxDecoration(
              color: event.type.accentColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.displayTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      _formatDate(event.occurredAt),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  event.displayNote,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (event.vetId != null || event.attachments.isNotEmpty) ...[
                  const SizedBox(height: 10),
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
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
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

class _UpcomingReminderCard extends StatelessWidget {
  const _UpcomingReminderCard({
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondarySoft,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 46,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
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
        return const Color(0xFFFF8A5B);
      case HealthRecordType.deworming:
        return const Color(0xFF60A5FA);
      case HealthRecordType.checkup:
        return const Color(0xFF22C55E);
      case HealthRecordType.grooming:
        return const Color(0xFFF59E0B);
      case HealthRecordType.medication:
        return const Color(0xFF8B5CF6);
      case HealthRecordType.allergy:
        return const Color(0xFFE11D48);
      case HealthRecordType.note:
        return AppColors.secondary500;
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

String _formatReminderDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/${value.year} $hour:$minute';
}
