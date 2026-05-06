import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_bottom_nav.dart';
import '../../pets/application/pet_list_provider.dart';
import '../../pets/domain/pet_profile.dart';
import '../application/reminder_providers.dart';
import '../data/reminder_api.dart';
import '../domain/reminder.dart';

class ReminderCalendarScreen extends ConsumerStatefulWidget {
  const ReminderCalendarScreen({super.key});

  @override
  ConsumerState<ReminderCalendarScreen> createState() =>
      _ReminderCalendarScreenState();
}

class _ReminderCalendarScreenState
    extends ConsumerState<ReminderCalendarScreen> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedPetId;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _draftDateTime = DateTime.now().add(const Duration(days: 1));
  ReminderRepeatRule _draftRepeatRule = ReminderRepeatRule.none;
  bool _isSaving = false;
  String? _saveError;

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final petsState = ref.watch(petBackendListProvider);
    final pets = petsState.maybeWhen(
      data: (items) => items,
      orElse: () => const <PetProfile>[],
    );
    final selectedPet = pets.isEmpty
        ? null
        : pets.firstWhere(
            (pet) => pet.id == (_selectedPetId ?? pets.first.id),
            orElse: () => pets.first,
          );
    final query = selectedPet == null
        ? null
        : ReminderListQuery(
            petId: selectedPet.id,
            from: DateTime(_visibleMonth.year, _visibleMonth.month),
            to: DateTime(_visibleMonth.year, _visibleMonth.month + 1),
            limit: 50,
          );
    final remindersState = query == null
        ? null
        : ref.watch(reminderListProvider(query));

    return Scaffold(
      bottomNavigationBar: const PawMateBottomNav(currentRoute: '/health'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: selectedPet == null ? null : () => _openCreateSheet(query),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Them lich'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 132),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/health'),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
                Expanded(
                  child: Text(
                    'Lich nhac',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Thong bao',
                  onPressed: () => context.go('/notifications'),
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Dong bo lich tiem phong, tay giun va tai kham tu backend.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            _PetSelector(
              pets: pets,
              selectedPetId: selectedPet?.id,
              isLoading: petsState.isLoading,
              onChanged: (value) => setState(() => _selectedPetId = value),
              onRetry: () => ref.invalidate(petBackendListProvider),
            ),
            const SizedBox(height: 18),
            _MonthHeader(
              month: _visibleMonth,
              onPrevious: () => setState(() {
                _visibleMonth = DateTime(
                  _visibleMonth.year,
                  _visibleMonth.month - 1,
                );
              }),
              onNext: () => setState(() {
                _visibleMonth = DateTime(
                  _visibleMonth.year,
                  _visibleMonth.month + 1,
                );
              }),
            ),
            const SizedBox(height: 12),
            if (query == null || remindersState == null)
              const _ReminderStatusCard(
                title: 'Chua co thu cung',
                message: 'Tao ho so thu cung truoc khi lap lich nhac.',
              )
            else
              ..._buildReminderContent(query, remindersState),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildReminderContent(
    ReminderListQuery query,
    AsyncValue<ReminderListResult> remindersState,
  ) {
    return remindersState.when(
      loading: () => const [
        _ReminderStatusCard(
          title: 'Dang dong bo lich nhac',
          message: 'PawMate dang tai lich nhac tu backend.',
          showProgress: true,
        ),
      ],
      error: (error, _) => [
        _ReminderStatusCard(
          title: 'Chua tai duoc lich nhac',
          message: _reminderErrorMessage(error),
          actionLabel: 'Thu lai',
          onAction: () => ref.invalidate(reminderListProvider(query)),
        ),
      ],
      data: (result) {
        return [
          _CalendarGrid(month: _visibleMonth, reminders: result.items),
          const SizedBox(height: 24),
          Text('Sap toi', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (result.items.isEmpty)
            const _ReminderStatusCard(
              title: 'Chua co lich nhac',
              message: 'Tao lich nhac dau tien de PawMate theo doi giup ban.',
            )
          else
            ...result.items.map(
              (reminder) => _ReminderCard(
                reminder: reminder,
                onDone: () => _markDone(reminder, query),
                onDelete: () => _deleteReminder(reminder, query),
              ),
            ),
        ];
      },
    );
  }

  void _openCreateSheet(ReminderListQuery? activeQuery) {
    _titleController.text = 'Tai kham dinh ky';
    _noteController.clear();
    _draftDateTime = DateTime.now().add(const Duration(days: 1));
    _draftRepeatRule = ReminderRepeatRule.none;
    _saveError = null;
    _isSaving = false;

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
                    'Them lich nhac',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Tieu de'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(labelText: 'Ghi chu'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _draftDateTime,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setSheetState(() {
                                _draftDateTime = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  _draftDateTime.hour,
                                  _draftDateTime.minute,
                                );
                              });
                            }
                          },
                          child: Text(_formatDate(_draftDateTime)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(
                                _draftDateTime,
                              ),
                            );
                            if (picked != null) {
                              setSheetState(() {
                                _draftDateTime = DateTime(
                                  _draftDateTime.year,
                                  _draftDateTime.month,
                                  _draftDateTime.day,
                                  picked.hour,
                                  picked.minute,
                                );
                              });
                            }
                          },
                          child: Text(_formatTime(_draftDateTime)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ReminderRepeatRule>(
                    initialValue: _draftRepeatRule,
                    decoration: const InputDecoration(labelText: 'Lap lai'),
                    items: ReminderRepeatRule.values
                        .map(
                          (rule) => DropdownMenuItem(
                            value: rule,
                            child: Text(rule.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => _draftRepeatRule = value);
                      }
                    },
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
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSaving
                          ? null
                          : () => _createReminder(
                              sheetContext,
                              setSheetState,
                              activeQuery,
                            ),
                      child: Text(_isSaving ? 'Dang luu...' : 'Luu lich nhac'),
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

  Future<void> _createReminder(
    BuildContext sheetContext,
    StateSetter setSheetState,
    ReminderListQuery? activeQuery,
  ) async {
    final pets = ref
        .read(petBackendListProvider)
        .maybeWhen(
          data: (items) => items,
          orElse: () => ref.read(petListProvider),
        );
    if (pets.isEmpty) {
      return;
    }

    final petId = _selectedPetId ?? pets.first.id;
    setSheetState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final accessToken = await ref.read(reminderAccessTokenProvider.future);
      if (accessToken == null) {
        throw const ReminderApiException(
          'Ban can dang nhap de luu lich nhac.',
          code: 'AUTH_REQUIRED',
          statusCode: 401,
        );
      }

      await ref
          .read(reminderApiProvider)
          .createReminder(
            petId,
            CreateReminderInput(
              title: _titleController.text,
              note: _noteController.text,
              reminderAt: _draftDateTime,
              repeatRule: _draftRepeatRule,
            ),
            accessToken: accessToken,
          );

      if (!mounted) {
        return;
      }

      if (activeQuery != null) {
        ref.invalidate(reminderListProvider(activeQuery));
      }
      ref.invalidate(upcomingRemindersProvider);
      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setSheetState(() {
        _isSaving = false;
        _saveError = _reminderErrorMessage(error);
      });
    }
  }

  Future<void> _markDone(Reminder reminder, ReminderListQuery query) async {
    final accessToken = await ref.read(reminderAccessTokenProvider.future);
    if (accessToken == null) {
      return;
    }
    await ref
        .read(reminderApiProvider)
        .markDone(reminder.petId, reminder.id, accessToken: accessToken);
    ref.invalidate(reminderListProvider(query));
    ref.invalidate(upcomingRemindersProvider);
  }

  Future<void> _deleteReminder(
    Reminder reminder,
    ReminderListQuery query,
  ) async {
    final accessToken = await ref.read(reminderAccessTokenProvider.future);
    if (accessToken == null) {
      return;
    }
    await ref
        .read(reminderApiProvider)
        .deleteReminder(reminder.petId, reminder.id, accessToken: accessToken);
    ref.invalidate(reminderListProvider(query));
    ref.invalidate(upcomingRemindersProvider);
  }
}

class _PetSelector extends StatelessWidget {
  const _PetSelector({
    required this.pets,
    required this.selectedPetId,
    required this.isLoading,
    required this.onChanged,
    required this.onRetry,
  });

  final List<PetProfile> pets;
  final String? selectedPetId;
  final bool isLoading;
  final ValueChanged<String?> onChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          const Icon(Icons.pets_rounded, color: AppColors.primary700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isLoading
                  ? 'Dang tai thu cung'
                  : pets.isEmpty
                  ? 'Chua co thu cung'
                  : 'Chon thu cung',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (pets.isEmpty && !isLoading)
            TextButton(onPressed: onRetry, child: const Text('Thu lai'))
          else if (pets.isNotEmpty)
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedPetId,
                items: pets
                    .map(
                      (pet) => DropdownMenuItem(
                        value: pet.id,
                        child: Text(pet.name),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Thang ${month.month}, ${month.year}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.month, required this.reminders});

  final DateTime month;
  final List<Reminder> reminders;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final leadingEmpty = firstDay.weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = <Widget>[
      for (final label in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'])
        Center(
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
      for (var index = 0; index < leadingEmpty; index++) const SizedBox(),
      for (var day = 1; day <= daysInMonth; day++)
        _DayCell(
          date: DateTime(month.year, month.month, day),
          count: reminders
              .where((reminder) => _isSameDate(reminder.dueAt, month, day))
              .length,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: cells,
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.date, required this.count});

  final DateTime date;
  final int count;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameCalendarDay(date, DateTime.now());
    return Container(
      decoration: BoxDecoration(
        color: isToday ? AppColors.primary500 : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '${date.day}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isToday ? Colors.white : AppColors.textPrimary,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          if (count > 0)
            Positioned(
              bottom: 5,
              child: Container(
                width: count > 1 ? 14 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isToday ? Colors.white : AppColors.tertiary500,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.onDone,
    required this.onDelete,
  });

  final Reminder reminder;
  final VoidCallback onDone;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary500,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(reminder.dueAt)} ${_formatTime(reminder.dueAt)}'
                  ' - ${reminder.repeatRule.label}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (reminder.note != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    reminder.note!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'done') {
                onDone();
              }
              if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'done', child: Text('Hoan thanh')),
              PopupMenuItem(value: 'delete', child: Text('Xoa')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReminderStatusCard extends StatelessWidget {
  const _ReminderStatusCard({
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
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

bool _isSameDate(DateTime value, DateTime month, int day) {
  return value.year == month.year &&
      value.month == month.month &&
      value.day == day;
}

bool _isSameCalendarDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _reminderErrorMessage(Object error) {
  if (error is ReminderApiException) {
    return error.message;
  }
  return 'Khong the dong bo lich nhac. Vui long thu lai.';
}
