import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_navigation.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_adaptive.dart';
import '../../../core/widgets/pawmate_bottom_nav.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../notifications/application/notification_providers.dart';
import '../../pets/application/pet_list_provider.dart';
import '../../pets/domain/pet_profile.dart';
import '../application/reminder_providers.dart';
import '../data/reminder_api.dart';
import '../domain/reminder.dart';

enum _ReminderFilter { active, upcoming, overdue, done, all }

extension on _ReminderFilter {
  String get label => switch (this) {
    _ReminderFilter.active => 'Đang nhắc',
    _ReminderFilter.upcoming => 'Sắp tới',
    _ReminderFilter.overdue => 'Trễ hạn',
    _ReminderFilter.done => 'Đã hoàn thành',
    _ReminderFilter.all => 'Tất cả',
  };

  String get sectionTitle => switch (this) {
    _ReminderFilter.active => 'Lịch hôm nay',
    _ReminderFilter.upcoming => 'Lịch sắp tới',
    _ReminderFilter.overdue => 'Lịch trễ hạn',
    _ReminderFilter.done => 'Đã hoàn thành',
    _ReminderFilter.all => 'Tất cả lịch nhắc',
  };
}

class ReminderCalendarScreen extends ConsumerStatefulWidget {
  const ReminderCalendarScreen({super.key, this.now});

  final DateTime Function()? now;

  @override
  ConsumerState<ReminderCalendarScreen> createState() =>
      _ReminderCalendarScreenState();
}

class _ReminderCalendarScreenState
    extends ConsumerState<ReminderCalendarScreen> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedPetId;
  _ReminderFilter _selectedFilter = _ReminderFilter.active;
  late DateTime _visibleMonth;
  late DateTime _draftDateTime;
  ReminderRepeatRule _draftRepeatRule = ReminderRepeatRule.none;
  bool _isSaving = false;
  String? _saveError;
  final Set<String> _busyReminderIds = <String>{};

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = _now();
    _visibleMonth = DateTime(now.year, now.month);
    _draftDateTime = now.add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cachedPets = ref.watch(petListProvider);
    final petsState = ref.watch(petBackendListProvider);
    final pets = petsState.maybeWhen(
      data: (items) => items,
      orElse: () => cachedPets,
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
            includeDone:
                _selectedFilter == _ReminderFilter.done ||
                _selectedFilter == _ReminderFilter.all,
          );
    final remindersState = query == null
        ? null
        : ref.watch(reminderListProvider(query));
    final useCompactFab =
        MediaQuery.sizeOf(context).width < 430 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.15;
    final horizontalPadding = useCompactFab ? 20.0 : 24.0;

    return Scaffold(
      bottomNavigationBar: const PawMateBottomNav(currentRoute: '/health'),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: useCompactFab
          ? FloatingActionButton(
              heroTag: 'reminder-create-fab',
              tooltip: 'Thêm lịch',
              backgroundColor: AppColors.primary500,
              foregroundColor: AppColors.white,
              onPressed: selectedPet == null
                  ? null
                  : () => _openCreateSheet(query),
              child: const Icon(Icons.add_rounded),
            )
          : FloatingActionButton.extended(
              heroTag: 'reminder-create-fab',
              onPressed: selectedPet == null
                  ? null
                  : () => _openCreateSheet(query),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm lịch'),
            ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            18,
            horizontalPadding,
            190,
          ),
          children: [
            _ReminderHeader(
              onBack: () => PawMateNavigation.backOrGo(context, '/health'),
              onFilter: _openFilterSheet,
            ),
            const SizedBox(height: 32),
            _NotificationPrompt(
              onEnable: () =>
                  context.go('/notifications?returnTo=%2Fhealth%2Freminders'),
            ),
            const SizedBox(height: 24),
            _SelectedPetChip(
              pets: pets,
              selectedPetId: selectedPet?.id,
              isLoading: petsState.isLoading,
              onChanged: (value) => setState(() => _selectedPetId = value),
              onRetry: () => ref.invalidate(petBackendListProvider),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                key: const ValueKey('reminder-active-filter-chip'),
                avatar: const Icon(Icons.filter_alt_outlined, size: 18),
                label: Text('Bộ lọc: ${_selectedFilter.label}'),
                onPressed: _openFilterSheet,
              ),
            ),
            const SizedBox(height: 22),
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
            const SizedBox(height: 22),
            if (query == null || remindersState == null)
              const _ReminderStatusCard(
                title: 'Chưa có thú cưng',
                message: 'Tạo hồ sơ thú cưng trước khi lập lịch nhắc.',
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
          title: 'Đang đồng bộ lịch nhắc',
          message: 'PawMate đang tải lịch nhắc từ backend.',
          showProgress: true,
        ),
      ],
      error: (error, _) => [
        _ReminderStatusCard(
          title: 'Chưa tải được lịch nhắc',
          message: _reminderErrorMessage(error),
          actionLabel: 'Thử lại',
          onAction: () => ref.invalidate(reminderListProvider(query)),
        ),
      ],
      data: (result) {
        final filteredItems = result.items
            .where(_matchesReminderFilter)
            .toList();
        return [
          _WeekStrip(
            month: _visibleMonth,
            reminders: filteredItems,
            now: _now(),
          ),
          const SizedBox(height: 34),
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedFilter.sectionTitle,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (_selectedFilter == _ReminderFilter.all) {
                    ref.invalidate(reminderListProvider(query));
                    return;
                  }
                  setState(() => _selectedFilter = _ReminderFilter.all);
                },
                child: Text(
                  _selectedFilter == _ReminderFilter.all
                      ? 'Làm mới'
                      : 'Xem tất cả',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (filteredItems.isEmpty)
            _ReminderStatusCard(
              title: 'Chưa có lịch nhắc',
              message:
                  'Không có lịch nhắc ở trạng thái ${_selectedFilter.label.toLowerCase()}.',
            )
          else
            ...filteredItems.map(
              (reminder) => _ReminderCard(
                reminder: reminder,
                now: _now(),
                petName: _selectedReminderPetName(reminder),
                isBusy: _busyReminderIds.contains(reminder.id),
                onDone: () => _markDone(reminder, query),
                onSnooze: () => _snoozeReminder(reminder, query),
                onDelete: () => _deleteReminder(reminder, query),
              ),
            ),
        ];
      },
    );
  }

  bool _matchesReminderFilter(Reminder reminder) {
    final isScheduled = reminder.status == ReminderStatus.scheduled;
    final isOverdue = reminder.dueAt.isBefore(_now()) && isScheduled;
    return switch (_selectedFilter) {
      _ReminderFilter.active => isScheduled,
      _ReminderFilter.upcoming => isScheduled && !isOverdue,
      _ReminderFilter.overdue => isOverdue,
      _ReminderFilter.done => reminder.status == ReminderStatus.done,
      _ReminderFilter.all => true,
    };
  }

  Future<void> _openFilterSheet() async {
    final selected = await showPawMateAdaptiveActionSheet<_ReminderFilter>(
      context: context,
      title: 'Lọc lịch nhắc',
      actions: [
        for (final filter in _ReminderFilter.values)
          PawMateAdaptiveAction(
            key: ValueKey('reminder-filter-${filter.name}'),
            label: filter.label,
            value: filter,
            icon: filter == _selectedFilter
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            isDefaultAction: filter == _selectedFilter,
          ),
      ],
    );
    if (selected != null && selected != _selectedFilter && mounted) {
      setState(() => _selectedFilter = selected);
    }
  }

  String _selectedReminderPetName(Reminder reminder) {
    final pets = ref
        .read(petBackendListProvider)
        .maybeWhen(
          data: (items) => items,
          orElse: () => ref.read(petListProvider),
        );
    for (final pet in pets) {
      if (pet.id == reminder.petId) {
        return pet.name;
      }
    }
    return pets.isEmpty ? 'Thú cưng' : pets.first.name;
  }

  void _openCreateSheet(ReminderListQuery? activeQuery) {
    _titleController.text = 'Tái khám định kỳ';
    _noteController.clear();
    _draftDateTime = _now().add(const Duration(days: 1));
    _draftRepeatRule = ReminderRepeatRule.none;
    _saveError = null;
    _isSaving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final compactSheet =
                MediaQuery.sizeOf(context).width < 360 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.15;
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  compactSheet ? 20 : 24,
                  24,
                  compactSheet ? 20 : 24,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thêm lịch nhắc',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('reminder-create-title-field'),
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Tiêu đề'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('reminder-create-note-field'),
                      controller: _noteController,
                      decoration: const InputDecoration(labelText: 'Ghi chú'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compactControls =
                            constraints.maxWidth < 320 ||
                            MediaQuery.textScalerOf(context).scale(1) > 1.15;
                        final dateButton = PawMateButton(
                          key: const ValueKey('reminder-create-date-button'),
                          label: _formatDate(_draftDateTime),
                          fullWidth: true,
                          compact: true,
                          variant: PawMateButtonVariant.secondary,
                          onPressed: () async {
                            final picked = await showPawMateAdaptiveDatePicker(
                              context: context,
                              initialDate: _draftDateTime,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                              currentDate: _now(),
                              title: 'Chọn ngày nhắc',
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
                        );
                        final timeButton = PawMateButton(
                          key: const ValueKey('reminder-create-time-button'),
                          label: _formatTime(_draftDateTime),
                          fullWidth: true,
                          compact: true,
                          variant: PawMateButtonVariant.secondary,
                          onPressed: () async {
                            final picked = await showPawMateAdaptiveTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(
                                _draftDateTime,
                              ),
                              title: 'Chọn giờ nhắc',
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
                        );

                        if (compactControls) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              dateButton,
                              const SizedBox(height: 10),
                              timeButton,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: dateButton),
                            const SizedBox(width: 10),
                            Expanded(child: timeButton),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ReminderRepeatRule>(
                      initialValue: _draftRepeatRule,
                      decoration: const InputDecoration(labelText: 'Lặp lại'),
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
                        key: const ValueKey('reminder-create-save-button'),
                        onPressed: _isSaving
                            ? null
                            : () => _createReminder(
                                sheetContext,
                                setSheetState,
                                activeQuery,
                              ),
                        child: Text(
                          _isSaving ? 'Đang lưu...' : 'Lưu lịch nhắc',
                        ),
                      ),
                    ),
                  ],
                ),
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
          'Bạn cần đăng nhập để lưu lịch nhắc.',
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

  Future<void> _markDone(Reminder reminder, ReminderListQuery query) =>
      _runReminderMutation(
        reminder: reminder,
        query: query,
        successMessage: 'Đã hoàn thành lịch nhắc.',
        action: (accessToken) => ref
            .read(reminderApiProvider)
            .markDone(reminder.petId, reminder.id, accessToken: accessToken),
      );

  Future<void> _snoozeReminder(Reminder reminder, ReminderListQuery query) =>
      _runReminderMutation(
        reminder: reminder,
        query: query,
        successMessage: 'Đã nhắc lại sau 1 giờ.',
        action: (accessToken) => ref
            .read(reminderApiProvider)
            .snoozeReminder(
              reminder.petId,
              reminder.id,
              _now().add(const Duration(hours: 1)),
              accessToken: accessToken,
            ),
      );

  Future<void> _deleteReminder(Reminder reminder, ReminderListQuery query) =>
      _runReminderMutation(
        reminder: reminder,
        query: query,
        successMessage: 'Đã xóa lịch nhắc.',
        action: (accessToken) => ref
            .read(reminderApiProvider)
            .deleteReminder(
              reminder.petId,
              reminder.id,
              accessToken: accessToken,
            ),
      );

  Future<void> _runReminderMutation({
    required Reminder reminder,
    required ReminderListQuery query,
    required String successMessage,
    required Future<void> Function(String accessToken) action,
  }) async {
    if (_busyReminderIds.contains(reminder.id)) {
      return;
    }
    setState(() => _busyReminderIds.add(reminder.id));
    try {
      final accessToken = await ref.read(reminderAccessTokenProvider.future);
      if (accessToken == null) {
        throw const ReminderApiException(
          'Bạn cần đăng nhập để cập nhật lịch nhắc.',
          code: 'AUTH_REQUIRED',
          statusCode: 401,
        );
      }
      await action(accessToken);
      ref.invalidate(reminderListProvider(query));
      ref.invalidate(upcomingRemindersProvider);
      ref.invalidate(notificationListProvider);
      if (mounted) {
        _showReminderSnack(successMessage);
      }
    } on Object catch (error) {
      if (mounted) {
        _showReminderSnack(_reminderErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busyReminderIds.remove(reminder.id));
      }
    }
  }

  void _showReminderSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReminderHeader extends StatelessWidget {
  const _ReminderHeader({required this.onBack, required this.onFilter});

  final VoidCallback onBack;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const ValueKey('reminder-back-button'),
          tooltip: 'Quay lại',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 32),
          color: AppColors.primary700,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Lịch nhắc nhở',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.appBarTitle(color: AppColors.primary700),
          ),
        ),
        IconButton(
          key: const ValueKey('reminder-filter-button'),
          tooltip: 'Bộ lọc lịch nhắc',
          onPressed: onFilter,
          icon: const Icon(Icons.tune_rounded, size: 32),
          color: AppColors.primary700,
        ),
      ],
    );
  }
}

class _NotificationPrompt extends StatelessWidget {
  const _NotificationPrompt({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.15;

    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 22,
        compact ? 18 : 22,
        compact ? 16 : 22,
        compact ? 18 : 22,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            color: AppColors.primary700,
            size: 34,
          ),
          SizedBox(width: compact ? 12 : 18),
          Expanded(
            child: Text(
              'Bật thông báo để không bỏ lỡ lịch của bé',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cardTitle(color: AppColors.primary700),
            ),
          ),
          SizedBox(width: compact ? 10 : 14),
          FilledButton(
            key: const ValueKey('reminder-notification-enable-button'),
            onPressed: onEnable,
            style: FilledButton.styleFrom(
              minimumSize: Size(compact ? 58 : 72, compact ? 48 : 56),
              padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('BẬT'),
          ),
        ],
      ),
    );
  }
}

class _SelectedPetChip extends StatelessWidget {
  const _SelectedPetChip({
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
    final selectedPet = pets.cast<PetProfile?>().firstWhere(
      (pet) => pet?.id == selectedPetId,
      orElse: () => pets.isEmpty ? null : pets.first,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.secondarySoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pets_rounded, color: AppColors.secondary500),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                isLoading
                    ? 'Đang tải thú cưng'
                    : pets.isEmpty
                    ? 'Chưa có thú cưng'
                    : selectedPet?.name ?? 'Chọn thú cưng',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.secondary500,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (pets.isEmpty && !isLoading)
              TextButton(onPressed: onRetry, child: const Text('Thử lại'))
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
                  icon: const Icon(
                    Icons.expand_more_rounded,
                    color: AppColors.secondary500,
                  ),
                  selectedItemBuilder: (context) => pets
                      .map((_) => const SizedBox(width: 1, height: 1))
                      .toList(),
                  onChanged: onChanged,
                ),
              ),
          ],
        ),
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
    return Row(
      children: [
        Expanded(
          child: Text(
            'Tháng ${month.month}, ${month.year}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.sectionTitle(),
          ),
        ),
        IconButton(
          tooltip: 'Tháng trước',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded, size: 34),
          color: AppColors.label,
        ),
        IconButton(
          tooltip: 'Tháng sau',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded, size: 34),
          color: AppColors.label,
        ),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.month,
    required this.reminders,
    required this.now,
  });

  final DateTime month;
  final List<Reminder> reminders;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final today = now;
    final anchor = month.year == today.year && month.month == today.month
        ? today
        : DateTime(month.year, month.month, 1);
    final start = anchor.subtract(Duration(days: anchor.weekday - 1));
    final days = List<DateTime>.generate(
      7,
      (index) => DateTime(start.year, start.month, start.day + index),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var index = 0; index < days.length; index++) ...[
            _WeekDayPill(
              date: days[index],
              selected: _isSameCalendarDay(days[index], today),
              count: reminders
                  .where(
                    (reminder) =>
                        _isSameCalendarDay(reminder.dueAt, days[index]),
                  )
                  .length,
            ),
            if (index != days.length - 1) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _WeekDayPill extends StatelessWidget {
  const _WeekDayPill({
    required this.date,
    required this.selected,
    required this.count,
  });

  final DateTime date;
  final bool selected;
  final int count;

  @override
  Widget build(BuildContext context) {
    final label = switch (date.weekday) {
      DateTime.monday => 'T2',
      DateTime.tuesday => 'T3',
      DateTime.wednesday => 'T4',
      DateTime.thursday => 'T5',
      DateTime.friday => 'T6',
      DateTime.saturday => 'T7',
      _ => 'CN',
    };

    return Container(
      width: 78,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: selected ? AppColors.mint : AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.meta(
              color: selected ? AppColors.deepGreen : AppColors.label,
            ),
          ),
          const SizedBox(height: 12),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Text(
                '${date.day}',
                style: AppTextStyles.cardTitle(
                  color: selected ? AppColors.deepGreen : AppColors.textPrimary,
                ),
              ),
              if (count > 0)
                Positioned(
                  bottom: -10,
                  child: Container(
                    width: count > 1 ? 16 : 8,
                    height: 6,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.deepGreen
                          : AppColors.primary500,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.now,
    required this.petName,
    required this.isBusy,
    required this.onDone,
    required this.onSnooze,
    required this.onDelete,
  });

  final Reminder reminder;
  final DateTime now;
  final String petName;
  final bool isBusy;
  final VoidCallback onDone;
  final VoidCallback onSnooze;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue =
        reminder.dueAt.isBefore(now) &&
        reminder.status == ReminderStatus.scheduled;
    final accent = _reminderAccent(reminder, isOverdue: isOverdue);

    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        color: isOverdue ? AppColors.errorSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isOverdue
              ? AppColors.errorSoft
              : AppColors.border.withValues(alpha: 0.55),
          width: isOverdue ? 1.6 : 1,
        ),
        boxShadow: AppShadows.soft,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isOverdue)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(24),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
                child: Text(
                  'TRỄ HẠN',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(22, 22, isOverdue ? 88 : 16, 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: accent.background,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(accent.icon, color: accent.foreground, size: 34),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardTitle(),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            isOverdue
                                ? Icons.access_time_rounded
                                : Icons.pets_rounded,
                            size: 20,
                            color: isOverdue
                                ? AppColors.error
                                : AppColors.label,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_formatTime(reminder.dueAt)} • $petName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isOverdue) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.error,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cần thực hiện sớm nhất có thể',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (reminder.note != null &&
                          reminder.note!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          reminder.note!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.label,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  key: ValueKey('reminder-menu-${reminder.id}'),
                  tooltip: 'Tùy chọn lịch nhắc',
                  enabled: !isBusy,
                  icon: isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onSelected: (value) {
                    if (value == 'done') {
                      onDone();
                    }
                    if (value == 'snooze') {
                      onSnooze();
                    }
                    if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    if (reminder.status == ReminderStatus.scheduled) ...const [
                      PopupMenuItem(value: 'done', child: Text('Hoàn thành')),
                      PopupMenuItem(
                        value: 'snooze',
                        child: Text('Nhắc lại sau 1 giờ'),
                      ),
                    ],
                    const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderAccent {
  const _ReminderAccent({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
}

_ReminderAccent _reminderAccent(Reminder reminder, {required bool isOverdue}) {
  if (isOverdue) {
    return const _ReminderAccent(
      icon: Icons.vaccines_outlined,
      background: AppColors.error,
      foreground: AppColors.white,
    );
  }

  final text = '${reminder.title} ${reminder.note ?? ''}'.toLowerCase();
  if (text.contains('thuốc')) {
    return const _ReminderAccent(
      icon: Icons.medication_outlined,
      background: AppColors.primarySoft,
      foreground: AppColors.primary700,
    );
  }
  if (text.contains('tẩy giun') || text.contains('giun')) {
    return const _ReminderAccent(
      icon: Icons.bug_report_outlined,
      background: AppColors.primarySoft,
      foreground: AppColors.primary700,
    );
  }

  return const _ReminderAccent(
    icon: Icons.medical_services_outlined,
    background: AppColors.secondarySoft,
    foreground: AppColors.secondary500,
  );
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
  return 'Không thể đồng bộ lịch nhắc. Vui lòng thử lại.';
}
