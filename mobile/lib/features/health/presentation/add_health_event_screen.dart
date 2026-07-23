import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_navigation.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_adaptive.dart';
import '../../pets/application/pet_list_provider.dart';
import '../../pets/domain/pet_profile.dart';
import '../../reminders/application/reminder_providers.dart';
import '../application/health_record_providers.dart';
import '../data/health_record_api.dart';
import '../domain/health_record.dart';

class AddHealthEventScreen extends ConsumerStatefulWidget {
  const AddHealthEventScreen({super.key, this.initialPetId, this.initialDate});

  final String? initialPetId;
  final DateTime? initialDate;

  @override
  ConsumerState<AddHealthEventScreen> createState() =>
      _AddHealthEventScreenState();
}

class _AddHealthEventScreenState extends ConsumerState<AddHealthEventScreen> {
  final _clinicController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedPetId;
  HealthRecordType _selectedType = HealthRecordType.vaccination;
  late DateTime _selectedDate;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 30);
  bool _isSaving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _selectedPetId = widget.initialPetId;
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _clinicController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cachedPets = ref.watch(petListProvider);
    final syncedPetsState = ref.watch(petBackendListProvider);
    final pets = syncedPetsState.maybeWhen(
      data: (items) => items,
      orElse: () => cachedPets,
    );
    final effectivePetId = _resolveSelectedPetId(pets);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 132),
              children: [
                _AddHealthHeader(
                  onBack: () => PawMateNavigation.backOrGo(context, '/health'),
                ),
                const SizedBox(height: 32),
                _SectionHeader(
                  title: 'Chọn thú cưng',
                  trailing: syncedPetsState.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
                const SizedBox(height: 18),
                if (pets.isEmpty)
                  _EmptyPetNotice(
                    onCreatePet: () => context.push(
                      '/pets/create?returnTo=%2Fhealth%2Fevents%2Fnew',
                    ),
                  )
                else
                  _PetSelector(
                    pets: pets,
                    selectedPetId: effectivePetId,
                    onSelect: (petId) => setState(() => _selectedPetId = petId),
                    onCreatePet: () => context.push(
                      '/pets/create?returnTo=%2Fhealth%2Fevents%2Fnew',
                    ),
                  ),
                const SizedBox(height: 42),
                _SectionHeader(
                  title: 'Loại sự kiện',
                  trailing: Text(
                    '* Bắt buộc',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _EventTypeGrid(
                  selectedType: _selectedType,
                  onSelected: (type) => setState(() => _selectedType = type),
                ),
                const SizedBox(height: 32),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 340;

                    if (isNarrow) {
                      return Column(
                        children: [
                          _PickerField(
                            key: const Key('add-health-date-field'),
                            label: 'Ngày thực hiện',
                            value: _formatDisplayDate(_selectedDate),
                            icon: Icons.calendar_month_outlined,
                            onTap: _pickDate,
                          ),
                          const SizedBox(height: 18),
                          _PickerField(
                            key: const Key('add-health-time-field'),
                            label: 'Giờ',
                            value: _formatTime(_selectedTime),
                            icon: Icons.schedule_rounded,
                            onTap: _pickTime,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: _PickerField(
                            key: const Key('add-health-date-field'),
                            label: 'Ngày thực hiện',
                            value: _formatDisplayDate(_selectedDate),
                            icon: Icons.calendar_month_outlined,
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _PickerField(
                            key: const Key('add-health-time-field'),
                            label: 'Giờ',
                            value: _formatTime(_selectedTime),
                            icon: Icons.schedule_rounded,
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                _FieldLabel('Phòng khám (Tùy chọn)'),
                const SizedBox(height: 12),
                _TextInputShell(
                  child: TextField(
                    key: const Key('add-health-clinic-input'),
                    controller: _clinicController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      icon: Icon(Icons.search_rounded),
                      hintText: 'Tìm kiếm phòng khám...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                _FieldLabel('Ghi chú sức khỏe'),
                const SizedBox(height: 12),
                _TextInputShell(
                  minHeight: 184,
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
                  child: TextField(
                    key: const Key('add-health-note-input'),
                    controller: _noteController,
                    maxLines: 7,
                    minLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText:
                          'Bé Mochi vừa tiêm nhắc lại mũi 5 bệnh. Cần theo dõi phản ứng trong 24h tới.',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 18),
                    ),
                  ),
                ),
                if (_saveError != null) ...[
                  const SizedBox(height: 16),
                  _SaveError(message: _saveError!),
                ],
              ],
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 18,
              child: _SaveButton(
                key: const Key('add-health-save-button'),
                isSaving: _isSaving,
                enabled: !_isSaving && effectivePetId != null,
                onPressed: effectivePetId == null
                    ? null
                    : () => _saveEvent(effectivePetId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _resolveSelectedPetId(List<PetProfile> pets) {
    if (pets.isEmpty) {
      return null;
    }
    final selected = _selectedPetId;
    if (selected != null && pets.any((pet) => pet.id == selected)) {
      return selected;
    }
    return pets.first.id;
  }

  Future<void> _pickDate() async {
    final picked = await showPawMateAdaptiveDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      currentDate: DateTime.now(),
      title: 'Chọn ngày sự kiện',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showPawMateAdaptiveTimePicker(
      context: context,
      initialTime: _selectedTime,
      title: 'Chọn giờ sự kiện',
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _saveEvent(String petId) async {
    setState(() {
      _isSaving = true;
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

      final eventDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      await ref
          .read(healthRecordApiProvider)
          .createRecord(
            petId,
            CreateHealthRecordInput(
              type: _selectedType,
              date: eventDate,
              time: _formatTime(_selectedTime),
              title: _eventTitle(_selectedType),
              note: _noteController.text,
              vetId: _clinicController.text,
            ),
            accessToken: accessToken,
          );

      ref.invalidate(
        healthRecordListProvider(HealthRecordListQuery(petId: petId)),
      );
      for (final type in HealthRecordType.values) {
        ref.invalidate(
          healthRecordListProvider(
            HealthRecordListQuery(petId: petId, type: type),
          ),
        );
      }
      ref.invalidate(upcomingRemindersProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu sự kiện sức khỏe.')));
      PawMateNavigation.backOrGo(context, '/health');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _saveError = _errorMessage(error);
      });
    }
  }
}

class _AddHealthHeader extends StatelessWidget {
  const _AddHealthHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const Key('add-health-back-button'),
          tooltip: 'Quay lại',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.primary500,
          iconSize: 30,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Thêm sự kiện sức khỏe',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.appBarTitle(),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _FieldLabel(title)),
        ?trailing,
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.label(color: AppColors.textSecondary),
    );
  }
}

class _PetSelector extends StatelessWidget {
  const _PetSelector({
    required this.pets,
    required this.selectedPetId,
    required this.onSelect,
    required this.onCreatePet,
  });

  final List<PetProfile> pets;
  final String? selectedPetId;
  final ValueChanged<String> onSelect;
  final VoidCallback onCreatePet;

  @override
  Widget build(BuildContext context) {
    final visiblePets = pets.take(2).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final pet in visiblePets) ...[
            _PetOption(
              pet: pet,
              selected: pet.id == selectedPetId,
              onTap: () => onSelect(pet.id),
            ),
            const SizedBox(width: 24),
          ],
          _AddPetOption(onTap: onCreatePet),
        ],
      ),
    );
  }
}

class _PetOption extends StatelessWidget {
  const _PetOption({
    required this.pet,
    required this.selected,
    required this.onTap,
  });

  final PetProfile pet;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('add-health-pet-${pet.id}'),
      borderRadius: BorderRadius.circular(56),
      onTap: onTap,
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.primary500 : AppColors.border,
                      width: selected ? 4 : 0,
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundColor: AppColors.surfaceContainer,
                    backgroundImage: _petAvatar(pet),
                    child: pet.avatarPath == null
                        ? Text(
                            _petInitial(pet.name),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                ),
                if (selected)
                  Positioned(
                    right: 0,
                    bottom: 4,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.deepGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 3),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: AppColors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              pet.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: selected
                    ? AppColors.primary500
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPetOption extends StatelessWidget {
  const _AddPetOption({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('add-health-add-pet-option'),
      borderRadius: BorderRadius.circular(56),
      onTap: onTap,
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 4),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.textMuted,
                size: 38,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Thêm',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPetNotice extends StatelessWidget {
  const _EmptyPetNotice({required this.onCreatePet});

  final VoidCallback onCreatePet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chưa có thú cưng',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tạo hồ sơ thú cưng trước khi lưu sự kiện sức khỏe.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onCreatePet,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm thú cưng'),
          ),
        ],
      ),
    );
  }
}

class _EventTypeGrid extends StatelessWidget {
  const _EventTypeGrid({required this.selectedType, required this.onSelected});

  final HealthRecordType selectedType;
  final ValueChanged<HealthRecordType> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = const [
      HealthRecordType.vaccination,
      HealthRecordType.checkup,
      HealthRecordType.deworming,
    ];

    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          Expanded(
            child: _EventTypeCard(
              type: options[i],
              selected: selectedType == options[i],
              onTap: () => onSelected(options[i]),
            ),
          ),
          if (i != options.length - 1) const SizedBox(width: 14),
        ],
      ],
    );
  }
}

class _EventTypeCard extends StatelessWidget {
  const _EventTypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final HealthRecordType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('add-health-event-type-${type.apiValue}'),
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 124,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.deepGreen : Colors.transparent,
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? const []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_eventIcon(type), color: AppColors.brown, size: 24),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                _eventLabel(type),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  height: 1.12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 12),
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(icon, color: AppColors.textMuted, size: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TextInputShell extends StatelessWidget {
  const _TextInputShell({
    required this.child,
    this.minHeight = 62,
    this.padding = const EdgeInsets.symmetric(horizontal: 18),
  });

  final Widget child;
  final double minHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

class _SaveError extends StatelessWidget {
  const _SaveError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    super.key,
    required this.isSaving,
    required this.enabled,
    required this.onPressed,
  });

  final bool isSaving;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary500,
          disabledBackgroundColor: AppColors.surfaceContainer,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          textStyle: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        onPressed: enabled ? onPressed : null,
        icon: isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : const Icon(Icons.save_rounded, size: 28),
        label: Text(isSaving ? 'Đang lưu...' : 'Lưu sự kiện'),
      ),
    );
  }
}

ImageProvider? _petAvatar(PetProfile pet) {
  final path = pet.avatarPath;
  if (path == null || path.trim().isEmpty) {
    return null;
  }
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }
  return AssetImage(path);
}

String _petInitial(String name) {
  final cleanName = name.trim();
  if (cleanName.isEmpty) {
    return '?';
  }
  return cleanName.substring(0, 1).toUpperCase();
}

IconData _eventIcon(HealthRecordType type) {
  switch (type) {
    case HealthRecordType.vaccination:
      return Icons.vaccines_outlined;
    case HealthRecordType.checkup:
      return Icons.medical_services_outlined;
    case HealthRecordType.deworming:
      return Icons.bug_report_outlined;
    case HealthRecordType.grooming:
      return Icons.content_cut_rounded;
    case HealthRecordType.medication:
      return Icons.medication_liquid_outlined;
    case HealthRecordType.allergy:
      return Icons.health_and_safety_outlined;
    case HealthRecordType.note:
      return Icons.notes_rounded;
  }
}

String _eventLabel(HealthRecordType type) {
  switch (type) {
    case HealthRecordType.checkup:
      return 'Khám định kỳ';
    default:
      return type.label;
  }
}

String _eventTitle(HealthRecordType type) {
  switch (type) {
    case HealthRecordType.checkup:
      return 'Khám định kỳ';
    default:
      return type.defaultTitle;
  }
}

String _formatDisplayDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

String _formatTime(TimeOfDay value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _errorMessage(Object error) {
  if (error is HealthRecordApiException) {
    return error.message;
  }
  return 'Không thể lưu sự kiện lúc này. Vui lòng thử lại.';
}
