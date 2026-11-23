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
import '../../pets/presentation/widgets/pet_avatar_media.dart';
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
                  : () => _openReminderSheet(query),
              child: const Icon(Icons.add_rounded),
            )
          : FloatingActionButton.extended(
              heroTag: 'reminder-create-fab',
              onPressed: selectedPet == null
                  ? null
                  : () => _openReminderSheet(query),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm lịch'),
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 190),
          children: [
            _ReminderHeader(
              selectedPet: selectedPet,
              pets: pets,
              onPetChanged: (value) => setState(() => _selectedPetId = value),
              onBack: () => PawMateNavigation.backOrGo(context, '/health'),
              onFilter: _openFilterSheet,
            ),
            const SizedBox(height: 12),
            _NotificationPrompt(
              onEnable: () =>
                  context.go('/notifications?returnTo=%2Fhealth%2Freminders'),
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
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
        final usesExpandedTextLayout =
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final sectionTitle = Text(
          _selectedFilter.sectionTitle,
          style: AppTextStyles.sectionTitle(),
        );
        final showAllButton = TextButton(
          onPressed: () {
            if (_selectedFilter == _ReminderFilter.all) {
              ref.invalidate(reminderListProvider(query));
              return;
            }
            setState(() => _selectedFilter = _ReminderFilter.all);
          },
          child: Text(
            _selectedFilter == _ReminderFilter.all ? 'Làm mới' : 'Xem tất cả',
          ),
        );
        return [
          _WeekStrip(
            month: _visibleMonth,
            reminders: filteredItems,
            now: _now(),
          ),
          const SizedBox(height: 24),
          if (usesExpandedTextLayout)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionTitle,
                Align(alignment: Alignment.centerRight, child: showAllButton),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: sectionTitle),
                showAllButton,
              ],
            ),
          const SizedBox(height: 8),
          if (filteredItems.isEmpty)
            _ReminderStatusCard(
              title: 'Chưa có lịch nhắc',
              message:
                  'Không có lịch nhắc ở trạng thái ${_selectedFilter.label.toLowerCase()}.',
            )
          else
            ...filteredItems.map((reminder) {
              final pet = _selectedReminderPet(reminder);
              return _ReminderCard(
                reminder: reminder,
                now: _now(),
                petName: pet?.name ?? 'Thú cưng',
                petAvatarPath: pet?.avatarPath,
                isBusy: _busyReminderIds.contains(reminder.id),
                onDone: () => _markDone(reminder, query),
                onSnooze: () => _snoozeReminder(reminder, query),
                onEdit: () =>
                    _openReminderSheet(query, editingReminder: reminder),
                onDelete: () => _confirmDeleteReminder(reminder, query),
              );
            }),
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

  PetProfile? _selectedReminderPet(Reminder reminder) {
    final pets = ref
        .read(petBackendListProvider)
        .maybeWhen(
          data: (items) => items,
          orElse: () => ref.read(petListProvider),
        );
    for (final pet in pets) {
      if (pet.id == reminder.petId) {
        return pet;
      }
    }
    return pets.isEmpty ? null : pets.first;
  }

  void _openReminderSheet(
    ReminderListQuery? activeQuery, {
    Reminder? editingReminder,
  }) {
    final isEditing = editingReminder != null;
    _titleController.text = editingReminder?.title ?? 'Tái khám định kỳ';
    _noteController.text = editingReminder?.note ?? '';
    _draftDateTime =
        editingReminder?.dueAt ?? _now().add(const Duration(days: 1));
    _draftRepeatRule = editingReminder?.repeatRule ?? ReminderRepeatRule.none;
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
            final imeBottom = MediaQuery.viewInsetsOf(context).bottom;
            final visibleSheetHeight =
                (MediaQuery.sizeOf(context).height - imeBottom)
                    .clamp(0.0, double.infinity)
                    .toDouble();
            final saveAction = SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: ValueKey(
                  isEditing
                      ? 'reminder-edit-save-button'
                      : 'reminder-create-save-button',
                ),
                onPressed: _isSaving
                    ? null
                    : () => _saveReminder(
                        sheetContext,
                        setSheetState,
                        activeQuery,
                        editingReminder: editingReminder,
                      ),
                child: Text(
                  _isSaving
                      ? 'Đang lưu...'
                      : isEditing
                      ? 'Lưu thay đổi'
                      : 'Lưu lịch nhắc',
                ),
              ),
            );
            return SizedBox(
              // ModalBottomSheet positions its child from the physical bottom.
              // Reserve the keyboard area in the child's measured height so
              // the constrained, scrollable viewport is laid out above the
              // IME and remains hit-test-visible.
              height: imeBottom > 0 ? visibleSheetHeight + imeBottom : null,
              child: SafeArea(
                top: false,
                child: Padding(
                  // Padding the scroll content only makes the sheet taller. The
                  // outer inset shrinks the sheet's visible viewport, allowing
                  // its real save action to scroll above the IME.
                  padding: EdgeInsets.only(bottom: imeBottom),
                  child: ConstrainedBox(
                    key: const ValueKey('reminder-create-sheet-viewport'),
                    constraints: imeBottom > 0
                        ? BoxConstraints.tightFor(height: visibleSheetHeight)
                        : const BoxConstraints(),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        SingleChildScrollView(
                          key: const ValueKey('reminder-create-sheet-scroll'),
                          padding: EdgeInsets.fromLTRB(
                            compactSheet ? 20 : 24,
                            24,
                            compactSheet ? 20 : 24,
                            imeBottom > 0 ? 96 : 24,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing
                                    ? 'Chỉnh sửa lịch nhắc'
                                    : 'Thêm lịch nhắc',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                key: ValueKey(
                                  isEditing
                                      ? 'reminder-edit-title-field'
                                      : 'reminder-create-title-field',
                                ),
                                controller: _titleController,
                                decoration: const InputDecoration(
                                  labelText: 'Tiêu đề',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                key: ValueKey(
                                  isEditing
                                      ? 'reminder-edit-note-field'
                                      : 'reminder-create-note-field',
                                ),
                                controller: _noteController,
                                decoration: const InputDecoration(
                                  labelText: 'Ghi chú',
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final compactControls =
                                      constraints.maxWidth < 320 ||
                                      MediaQuery.textScalerOf(
                                            context,
                                          ).scale(1) >
                                          1.15;
                                  final dateButton = PawMateButton(
                                    key: const ValueKey(
                                      'reminder-create-date-button',
                                    ),
                                    label: _formatDate(_draftDateTime),
                                    fullWidth: true,
                                    compact: true,
                                    variant: PawMateButtonVariant.secondary,
                                    onPressed: () async {
                                      final picked =
                                          await showPawMateAdaptiveDatePicker(
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
                                    key: const ValueKey(
                                      'reminder-create-time-button',
                                    ),
                                    label: _formatTime(_draftDateTime),
                                    fullWidth: true,
                                    compact: true,
                                    variant: PawMateButtonVariant.secondary,
                                    onPressed: () async {
                                      final picked =
                                          await showPawMateAdaptiveTimePicker(
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
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
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Lặp lại',
                                ),
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
                                    setSheetState(
                                      () => _draftRepeatRule = value,
                                    );
                                  }
                                },
                              ),
                              if (_saveError != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _saveError!,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                              if (imeBottom == 0) ...[
                                const SizedBox(height: 18),
                                saveAction,
                              ],
                            ],
                          ),
                        ),
                        if (imeBottom > 0)
                          Positioned(
                            left: compactSheet ? 20 : 24,
                            right: compactSheet ? 20 : 24,
                            bottom: 12,
                            child: saveAction,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveReminder(
    BuildContext sheetContext,
    StateSetter setSheetState,
    ReminderListQuery? activeQuery, {
    Reminder? editingReminder,
  }) async {
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

      final input = CreateReminderInput(
        title: _titleController.text,
        note: _noteController.text,
        reminderAt: _draftDateTime,
        repeatRule: _draftRepeatRule,
      );
      if (editingReminder == null) {
        await ref
            .read(reminderApiProvider)
            .createReminder(petId, input, accessToken: accessToken);
      } else {
        await ref
            .read(reminderApiProvider)
            .updateReminder(
              editingReminder.petId,
              editingReminder.id,
              input,
              accessToken: accessToken,
            );
      }

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

  Future<void> _confirmDeleteReminder(
    Reminder reminder,
    ReminderListQuery query,
  ) async {
    final confirmed = await showPawMateAdaptiveDialog<bool>(
      context: context,
      title: 'Xóa lịch nhắc?',
      message: 'Bạn có thể tạo lại lịch nhắc sau.',
      actions: const [
        PawMateAdaptiveAction<bool>(label: 'Hủy'),
        PawMateAdaptiveAction<bool>(
          label: 'Xóa',
          value: true,
          isDestructiveAction: true,
        ),
      ],
    );

    if (confirmed == true && mounted) {
      await _deleteReminder(reminder, query);
    }
  }

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
  const _ReminderHeader({
    required this.selectedPet,
    required this.pets,
    required this.onPetChanged,
    required this.onBack,
    required this.onFilter,
  });

  final PetProfile? selectedPet;
  final List<PetProfile> pets;
  final ValueChanged<String?> onPetChanged;
  final VoidCallback onBack;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PawMateAdaptiveBackButton(
          key: const ValueKey('reminder-back-button'),
          onPressed: onBack,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PopupMenuButton<String>(
            key: const ValueKey('reminder-pet-selector'),
            tooltip: 'Chọn thú cưng',
            padding: EdgeInsets.zero,
            initialValue: selectedPet?.id,
            enabled: pets.isNotEmpty,
            onSelected: onPetChanged,
            itemBuilder: (context) => pets
                .map(
                  (pet) => PopupMenuItem<String>(
                    value: pet.id,
                    child: Text(pet.name),
                  ),
                )
                .toList(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lịch nhắc nhở',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.appBarTitle(
                        color: AppColors.primary700,
                      ),
                    ),
                    if (selectedPet != null)
                      Text(
                        selectedPet!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.micro(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('reminder-filter-button'),
          tooltip: 'Bộ lọc lịch nhắc',
          onPressed: onFilter,
          icon: const Icon(Icons.tune_rounded, size: 24),
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
    return Container(
      key: const ValueKey('reminder-notification-prompt'),
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            color: AppColors.primary700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bật thông báo để không bỏ lỡ lịch của bé',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(color: AppColors.primary700),
            ),
          ),
          const SizedBox(width: 8),
          PawMateButton(
            key: const ValueKey('reminder-notification-enable-button'),
            label: 'BẬT',
            onPressed: onEnable,
            fullWidth: false,
            compact: true,
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
    return Row(
      children: [
        Expanded(
          child: Text(
            'Tháng ${month.month}, ${month.year}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.h4(),
          ),
        ),
        IconButton(
          tooltip: 'Tháng trước',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded, size: 24),
          color: AppColors.label,
        ),
        IconButton(
          tooltip: 'Tháng sau',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded, size: 24),
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
            if (index != days.length - 1) const SizedBox(width: 8),
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
      key: ValueKey(
        'reminder-day-${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      ),
      width: 44,
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.mint : Colors.transparent,
        border: selected ? null : Border.all(color: Colors.transparent),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.meta(
              color: selected ? AppColors.deepGreen : AppColors.label,
            ),
          ),
          const SizedBox(height: 4),
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
    required this.petAvatarPath,
    required this.isBusy,
    required this.onDone,
    required this.onSnooze,
    required this.onEdit,
    required this.onDelete,
  });

  final Reminder reminder;
  final DateTime now;
  final String petName;
  final String? petAvatarPath;
  final bool isBusy;
  final VoidCallback onDone;
  final VoidCallback onSnooze;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isOverdue =
        reminder.dueAt.isBefore(now) &&
        reminder.status == ReminderStatus.scheduled;
    final accent = _reminderAccent(reminder, isOverdue: isOverdue);
    final useStackedTitleAndTime =
        MediaQuery.textScalerOf(context).scale(1) >= 1.3;

    return Container(
      key: ValueKey('reminder-card-${reminder.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isOverdue ? AppColors.surfaceContainer : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue
              ? AppColors.mint
              : AppColors.border.withValues(alpha: 0.55),
          width: isOverdue ? 1.2 : 1,
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
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.brown,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(15),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
                child: Text(
                  'TRỄ HẠN',
                  style: AppTextStyles.micro(color: AppColors.white),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(accent.icon, color: accent.foreground, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isOverdue)
                        Text(
                          reminder.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.cardTitle(),
                        )
                      else if (useStackedTitleAndTime)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reminder.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.cardTitle(),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(reminder.dueAt),
                              style: AppTextStyles.body(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                reminder.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.cardTitle(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(reminder.dueAt),
                              style: AppTextStyles.body(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 4),
                      if (isOverdue)
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 16,
                              color: AppColors.brown,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${_formatTime(reminder.dueAt)} • $petName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            SizedBox.square(
                              dimension: 18,
                              child: ClipOval(
                                child: PetAvatarMedia(
                                  source: petAvatarPath,
                                  semanticLabel: 'Ảnh của $petName',
                                  fallback: ColoredBox(
                                    color: AppColors.secondarySoft,
                                    child: Center(
                                      child: Text(
                                        petName.characters.first.toUpperCase(),
                                        style: AppTextStyles.micro(
                                          color: AppColors.secondary500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                petName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (isOverdue) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.brown,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Cần thực hiện sớm nhất có thể',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.captionStrong(
                                  color: AppColors.brown,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (reminder.note != null &&
                          reminder.note!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          reminder.note!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption(color: AppColors.label),
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
                    if (value == 'edit') {
                      onEdit();
                    }
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
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Chỉnh sửa'),
                    ),
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
      background: AppColors.brown,
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
