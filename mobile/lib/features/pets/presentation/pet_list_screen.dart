import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_bottom_nav.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../../core/widgets/pawmate_skeleton.dart';
import '../../../core/widgets/pawmate_state_view.dart';
import '../../auth/application/auth_session_coordinator.dart';
import '../../reminders/application/reminder_providers.dart';
import '../../reminders/data/reminder_api.dart';
import '../../reminders/domain/reminder.dart';
import '../application/pet_list_provider.dart';
import '../data/pet_api.dart';
import '../domain/pet_profile.dart';
import 'widgets/pet_avatar_media.dart';

class PetHomeScreen extends ConsumerWidget {
  const PetHomeScreen({super.key, this.now});

  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cachedPets = ref.watch(petListProvider);
    final backendPetsState = ref.watch(petBackendListProvider);
    final sessionState = ref.watch(authSessionSnapshotProvider);
    final remindersState = ref.watch(upcomingRemindersProvider);
    final selectedPetId = ref.watch(selectedPetIdProvider);
    final pets = backendPetsState.maybeWhen(
      data: (items) => items,
      orElse: () => cachedPets,
    );
    final selectedPet = pets.isEmpty
        ? null
        : pets.firstWhere(
            (pet) => pet.id == selectedPetId,
            orElse: () => pets.first,
          );
    final primaryReminder = remindersState.maybeWhen(
      data: (items) => _reminderForSelectedPet(items, selectedPet?.id),
      orElse: () => null,
    );
    final displayName = sessionState.maybeWhen(
      data: (session) => _homeGreetingName(session?.user.displayName),
      orElse: () => 'bạn',
    );
    return Scaffold(
      bottomNavigationBar: const PawMateBottomNav(currentRoute: '/pets'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (pets.isEmpty && backendPetsState.isLoading) {
            return const _PetListLoadingState();
          }

          if (pets.isEmpty && backendPetsState.hasError) {
            return _PetSyncError(
              error: backendPetsState.error!,
              message: _petSyncErrorMessage(backendPetsState.error!),
              onRetry: () => ref.invalidate(petBackendListProvider),
            );
          }

          if (pets.isEmpty) {
            return PawMateStateView(
              key: const Key('home-pets-empty-state'),
              type: PawMateStateType.empty,
              title: 'Chưa có thú cưng nào',
              message:
                  'Thêm hồ sơ đầu tiên để theo dõi thông tin và sức khỏe của bé.',
              primaryActionLabel: 'Thêm thú cưng',
              onPrimaryAction: () => _openPetForm(context, returnTo: '/pets'),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    MediaQuery.paddingOf(context).top + 10,
                    16,
                    8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HomeHeader(
                        displayName: displayName,
                        onOpenVetList: () => context.go('/vets/list'),
                        onOpenNotifications: () =>
                            context.go('/notifications?returnTo=%2Fpets'),
                        onOpenProfile: () => context.go('/profile'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Chào buổi sáng, $displayName!',
                        style: AppTextStyles.bodyStrong(),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hôm nay thú cưng của bạn thế nào?',
                        style: AppTextStyles.bodyCompact(),
                      ),
                      const SizedBox(height: 24),
                      _HomePetCarousel(
                        pets: pets,
                        selectedPetId: selectedPet?.id,
                        onPetTap: (pet) {
                          ref
                              .read(selectedPetIdProvider.notifier)
                              .select(pet.id);
                          context.push('/pets/${pet.id}');
                        },
                      ),
                      const SizedBox(height: 48),
                      if (backendPetsState.hasError) ...[
                        _PetSyncBanner(
                          message: _petSyncErrorMessage(
                            backendPetsState.error!,
                          ),
                          onRetry: () => ref.invalidate(petBackendListProvider),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _HomeEntrySection(
                        selectedPet: selectedPet,
                        reminder: primaryReminder,
                        now: now ?? DateTime.now(),
                        onDeferReminder: primaryReminder == null
                            ? null
                            : () => _snoozeHomeReminder(
                                context,
                                ref,
                                primaryReminder,
                                now ?? DateTime.now(),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 132)),
            ],
          );
        },
      ),
    );
  }
}

Reminder? _reminderForSelectedPet(
  List<Reminder> reminders,
  String? selectedPetId,
) {
  if (reminders.isEmpty) {
    return null;
  }
  if (selectedPetId == null) {
    return reminders.first;
  }
  for (final reminder in reminders) {
    if (reminder.petId == selectedPetId) {
      return reminder;
    }
  }
  return null;
}

Future<void> _snoozeHomeReminder(
  BuildContext context,
  WidgetRef ref,
  Reminder reminder,
  DateTime now,
) async {
  try {
    final accessToken = await ref.read(reminderAccessTokenProvider.future);
    if (!context.mounted) {
      return;
    }
    if (accessToken == null) {
      _showHomeMessage(context, 'Bạn cần đăng nhập để dời lịch nhắc.');
      return;
    }

    await ref
        .read(reminderApiProvider)
        .snoozeReminder(
          reminder.petId,
          reminder.id,
          now.add(const Duration(hours: 1)),
          accessToken: accessToken,
        );
    ref.invalidate(upcomingRemindersProvider);
    if (!context.mounted) {
      return;
    }
    _showHomeMessage(context, 'Đã nhắc lại sau 1 giờ.');
  } on ReminderApiException catch (error) {
    if (context.mounted) {
      _showHomeMessage(context, error.message);
    }
  } catch (_) {
    if (context.mounted) {
      _showHomeMessage(context, 'Chưa thể dời lịch nhắc. Vui lòng thử lại.');
    }
  }
}

void _showHomeMessage(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String _homeGreetingName(String? displayName) {
  final normalized = displayName?.trim();
  if (normalized == null || normalized.isEmpty) {
    return 'bạn';
  }
  return normalized.split(RegExp(r'\s+')).last;
}

String _initials(String displayName) {
  final parts = displayName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return 'PM';
  }
  if (parts.length == 1) {
    return parts.first.characters.first.toUpperCase();
  }
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}

String _homeReminderSubtitle(Reminder reminder, DateTime now) {
  final dueAt = reminder.dueAt.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final dueDate = DateTime(dueAt.year, dueAt.month, dueAt.day);
  final difference = dueDate.difference(today).inDays;
  final hour = dueAt.hour.toString().padLeft(2, '0');
  final minute = dueAt.minute.toString().padLeft(2, '0');
  final dateLabel = switch (difference) {
    0 => 'Hôm nay',
    1 => 'Ngày mai',
    _ =>
      '${dueAt.day.toString().padLeft(2, '0')}/'
          '${dueAt.month.toString().padLeft(2, '0')}/${dueAt.year}',
  };
  final note = reminder.note?.trim();
  return note == null || note.isEmpty
      ? '$dateLabel, $hour:$minute'
      : '$dateLabel, $hour:$minute • $note';
}

String _homePetHealthLabel(String healthStatus) {
  return switch (healthStatus.trim().toLowerCase()) {
    'healthy' || 'good' => 'KHỎE',
    'needs_vaccine' => 'CẦN TIÊM',
    _ => 'THEO DÕI',
  };
}

class PetListScreen extends ConsumerWidget {
  const PetListScreen({this.now, super.key});

  /// Optional clock used by deterministic UI stories and golden tests.
  ///
  /// Production keeps using the device clock when no value is supplied.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cachedPets = ref.watch(petListProvider);
    final backendPetsState = ref.watch(petBackendListProvider);
    final pets = backendPetsState.maybeWhen(
      data: (items) => items,
      orElse: () => cachedPets,
    );
    final theme = Theme.of(context);
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;

    return Scaffold(
      bottomNavigationBar: const PawMateBottomNav(currentRoute: '/pets'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (pets.isEmpty && backendPetsState.isLoading) {
              return const _PetListLoadingState();
            }

            if (pets.isEmpty && backendPetsState.hasError) {
              return _PetSyncError(
                error: backendPetsState.error!,
                message: _petSyncErrorMessage(backendPetsState.error!),
                onRetry: () => ref.invalidate(petBackendListProvider),
              );
            }

            if (pets.isEmpty) {
              return _EmptyPetListState(
                onCreate: () => _openPetForm(context, returnTo: '/pets/list'),
              );
            }

            final heroPet = pets.first;
            final secondaryPets = pets.skip(1).toList();
            final useThreeColumns = constraints.maxWidth >= 600;
            final gridColumnCount = useThreeColumns
                ? 3
                : usesExpandedTextLayout
                ? 1
                : 2;
            final currentDate = now ?? DateTime.now();

            return CustomScrollView(
              key: const Key('pet-list-scroll'),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PetListHeader(
                          onOpenNotifications: () => context.go(
                            '/notifications?returnTo=%2Fpets%2Flist',
                          ),
                          onOpenSearch: () => context.go('/pets/list'),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Chào buổi sáng, Nam!',
                          maxLines: usesExpandedTextLayout ? null : 1,
                          overflow: usesExpandedTextLayout
                              ? null
                              : TextOverflow.ellipsis,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cùng chăm sóc các bạn nhỏ hôm nay nhé.',
                          maxLines: usesExpandedTextLayout ? null : 1,
                          overflow: usesExpandedTextLayout
                              ? null
                              : TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 36),
                        _FeaturedPetCard(
                          pet: heroPet,
                          now: currentDate,
                          onTap: () => context.push('/pets/${heroPet.id}'),
                        ),
                        if (backendPetsState.hasError) ...[
                          const SizedBox(height: 14),
                          _PetSyncBanner(
                            message: _petSyncErrorMessage(
                              backendPetsState.error!,
                            ),
                            onRetry: () =>
                                ref.invalidate(petBackendListProvider),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridColumnCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: useThreeColumns ? 0.72 : 0.66,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index == secondaryPets.length) {
                        return _PetListAddCard(
                          onTap: () =>
                              _openPetForm(context, returnTo: '/pets/list'),
                        );
                      }

                      final pet = secondaryPets[index];
                      return _PetGridCard(
                        pet: pet,
                        now: currentDate,
                        onTap: () => context.push('/pets/${pet.id}'),
                      );
                    }, childCount: secondaryPets.length + 1),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.displayName,
    required this.onOpenVetList,
    required this.onOpenNotifications,
    required this.onOpenProfile,
  });

  final String displayName;
  final VoidCallback onOpenVetList;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;
    final title = Text(
      'PawMate',
      maxLines: usesExpandedTextLayout ? null : 1,
      overflow: usesExpandedTextLayout ? null : TextOverflow.ellipsis,
      style: theme.textTheme.titleLarge?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('home-vet-search-action'),
          tooltip: 'Tìm phòng khám',
          onPressed: onOpenVetList,
          icon: const Icon(Icons.search_rounded),
        ),
        IconButton(
          tooltip: 'Thông báo',
          onPressed: onOpenNotifications,
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        Semantics(
          button: true,
          label: 'Mở hồ sơ cá nhân',
          onTap: onOpenProfile,
          child: ExcludeSemantics(
            child: InkWell(
              key: const Key('home-profile-action'),
              onTap: onOpenProfile,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox.square(
                dimension: AppControlSize.minTouchTarget,
                child: Center(
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.careGreenSoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initials(displayName),
                      style: AppTextStyles.captionStrong(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    final branding = Row(
      children: [
        Icon(Icons.pets_rounded, size: 22, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(child: title),
      ],
    );
    if (usesExpandedTextLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          branding,
          const SizedBox(height: AppSpacing.s8),
          Align(alignment: Alignment.centerRight, child: actions),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: branding),
        actions,
      ],
    );
  }
}

class _HomePetCarousel extends StatelessWidget {
  const _HomePetCarousel({
    required this.pets,
    required this.selectedPetId,
    required this.onPetTap,
  });

  final List<PetProfile> pets;
  final String? selectedPetId;
  final ValueChanged<PetProfile> onPetTap;

  @override
  Widget build(BuildContext context) {
    final visiblePets = pets.take(2).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var index = 0; index < visiblePets.length; index++) ...[
            _HomePetAvatar(
              pet: visiblePets[index],
              selected: visiblePets[index].id == selectedPetId,
              statusLabel: _homePetHealthLabel(visiblePets[index].healthStatus),
              statusColor: visiblePets[index].healthStatus == 'needs_vaccine'
                  ? AppColors.primary500
                  : AppColors.careGreen,
              onTap: () => onPetTap(visiblePets[index]),
            ),
            SizedBox(width: index == 0 ? 40 : 22),
          ],
          _AddPetAvatar(onTap: () => _openPetForm(context, returnTo: '/pets')),
        ],
      ),
    );
  }
}

class _HomePetAvatar extends StatelessWidget {
  const _HomePetAvatar({
    required this.pet,
    required this.statusLabel,
    required this.statusColor,
    required this.selected,
    required this.onTap,
  });

  final PetProfile pet;
  final String statusLabel;
  final Color statusColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      selected: selected,
      label: '${pet.name}, tình trạng $statusLabel',
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          key: Key('home-pet-avatar-${pet.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(44),
          child: SizedBox(
            width: 104,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceMuted,
                        border: Border.all(
                          color: selected
                              ? statusColor
                              : AppColors.borderStrong,
                          width: 2,
                        ),
                        boxShadow: AppShadows.soft,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: PetAvatarMedia(
                        source: pet.avatarPath,
                        semanticLabel: 'Ảnh ${pet.name}',
                        fallback: Icon(
                          pet.species == 'cat'
                              ? Icons.cruelty_free_rounded
                              : Icons.pets_rounded,
                          color: AppColors.careGreen,
                          size: 34,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -7,
                      bottom: 8,
                      child: _MiniStatusBadge(
                        label: statusLabel,
                        backgroundColor: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  pet.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddPetAvatar extends StatelessWidget {
  const _AddPetAvatar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: 'Thêm thú cưng',
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          key: const Key('home-add-pet-avatar'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(44),
          child: SizedBox(
            width: 104,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border, width: 1.3),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 28,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Thêm',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.label,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStatusBadge extends StatelessWidget {
  const _MiniStatusBadge({required this.label, required this.backgroundColor});

  final String label;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.white, width: 1.5),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}

class _HomeEntrySection extends StatelessWidget {
  const _HomeEntrySection({
    required this.selectedPet,
    required this.reminder,
    required this.now,
    required this.onDeferReminder,
  });

  final PetProfile? selectedPet;
  final Reminder? reminder;
  final DateTime now;
  final Future<void> Function()? onDeferReminder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeHealthReminderCard(
          pet: selectedPet,
          reminder: reminder,
          now: now,
          onOpenTimeline: () => context.go('/health'),
          onBookReminder: () => context.go('/health/reminders'),
          onDeferReminder: onDeferReminder,
        ),
        const SizedBox(height: 20),
        _HomeEmergencyBanner(onTap: () => context.go('/rescue')),
        const SizedBox(height: 12),
        _HomeMainCards(
          onFindVet: () => context.go('/vets/map'),
          onOpenVetDetail: () => context.push('/vets/pethome-q7'),
          onOpenAdoption: () => context.go('/adoption'),
        ),
      ],
    );
  }
}

class _HomeHealthReminderCard extends StatelessWidget {
  const _HomeHealthReminderCard({
    required this.pet,
    required this.reminder,
    required this.now,
    required this.onOpenTimeline,
    required this.onBookReminder,
    required this.onDeferReminder,
  });

  final PetProfile? pet;
  final Reminder? reminder;
  final DateTime now;
  final VoidCallback onOpenTimeline;
  final VoidCallback onBookReminder;
  final Future<void> Function()? onDeferReminder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('home-health-reminder-card'),
        onTap: onOpenTimeline,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.favorite_rounded, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'LỊCH NHẮC SỨC KHỎE',
                      maxLines: usesExpandedTextLayout ? null : 1,
                      overflow: usesExpandedTextLayout
                          ? null
                          : TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                reminder?.title ??
                    (pet == null
                        ? 'Theo dõi sức khỏe thú cưng'
                        : 'Chưa có lịch nhắc cho ${pet!.name}'),
                maxLines: usesExpandedTextLayout ? null : 1,
                overflow: usesExpandedTextLayout ? null : TextOverflow.ellipsis,
                style: AppTextStyles.cardTitle(),
              ),
              const SizedBox(height: 4),
              Text(
                reminder == null
                    ? 'Tạo lịch tiêm phòng, tẩy giun hoặc tái khám.'
                    : _homeReminderSubtitle(reminder!, now),
                maxLines: usesExpandedTextLayout ? null : 2,
                overflow: usesExpandedTextLayout ? null : TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PawMateButton(
                    key: const Key('home-book-reminder-cta'),
                    label: reminder == null ? 'Tạo lịch' : 'Xác nhận',
                    onPressed: onBookReminder,
                    fullWidth: false,
                    compact: true,
                  ),
                  if (onDeferReminder != null)
                    PawMateButton(
                      key: const Key('home-defer-reminder-cta'),
                      label: 'Để sau',
                      onPressed: onDeferReminder,
                      variant: PawMateButtonVariant.secondary,
                      fullWidth: false,
                      compact: true,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeEmergencyBanner extends StatelessWidget {
  const _HomeEmergencyBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const alert = 'Mất Poodle trắng tại phường Tân Quý';
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;
    return Semantics(
      button: true,
      label: 'Tin khẩn cấp. $alert',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: AppColors.primary500,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: const Key('home-rescue-alert-card'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TIN KHẨN CẤP',
                          style: AppTextStyles.micro(
                            color: AppColors.white.withValues(alpha: 0.82),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alert,
                          maxLines: usesExpandedTextLayout ? null : 2,
                          overflow: usesExpandedTextLayout
                              ? null
                              : TextOverflow.ellipsis,
                          style: AppTextStyles.captionStrong(
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeMainCards extends StatelessWidget {
  const _HomeMainCards({
    required this.onFindVet,
    required this.onOpenVetDetail,
    required this.onOpenAdoption,
  });

  final VoidCallback onFindVet;
  final VoidCallback onOpenVetDetail;
  final VoidCallback onOpenAdoption;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320) {
          return Column(
            children: [
              _NearbyVetCard(onFindVet: onFindVet, onTap: onOpenVetDetail),
              const SizedBox(height: 12),
              _AdoptionTeaserCard(onTap: onOpenAdoption),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NearbyVetCard(
                onFindVet: onFindVet,
                onTap: onOpenVetDetail,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _AdoptionTeaserCard(onTap: onOpenAdoption)),
          ],
        );
      },
    );
  }
}

class _NearbyVetCard extends StatelessWidget {
  const _NearbyVetCard({required this.onFindVet, required this.onTap});

  final VoidCallback onFindVet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;

    return Material(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: const Key('home-nearby-vet-card'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PHÒNG KHÁM GẦN BẠN',
                maxLines: usesExpandedTextLayout ? null : 1,
                overflow: usesExpandedTextLayout ? null : TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.careGreen.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'PetHome Q7',
                maxLines: usesExpandedTextLayout ? null : 1,
                overflow: usesExpandedTextLayout ? null : TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.careGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: AppSpacing.s4,
                runSpacing: 2,
                children: [
                  Text(
                    'Google',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '★ 4.8',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (usesExpandedTextLayout) ...[
                _HomeClinicImage(height: 96),
                const SizedBox(height: AppSpacing.s8),
                PawMateButton(
                  key: const Key('home-find-vet-shortcut'),
                  label: 'Gọi ngay',
                  onPressed: onFindVet,
                  leadingIcon: Icons.call_rounded,
                  compact: true,
                ),
              ] else
                SizedBox(
                  height: 82,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const _HomeClinicImage(height: 82),
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: PawMateButton(
                          key: const Key('home-find-vet-shortcut'),
                          label: 'Gọi ngay',
                          onPressed: onFindVet,
                          leadingIcon: Icons.call_rounded,
                          fullWidth: false,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeClinicImage extends StatelessWidget {
  const _HomeClinicImage({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Không gian tiếp đón của phòng khám PetHome Q7',
      child: Container(
        key: const Key('home-nearby-vet-image'),
        height: height,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Image.asset(
          'assets/images/brand/pawmate_vet_clinic_reception.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, _, _) => const Center(
            child: Icon(
              Icons.local_hospital_outlined,
              color: AppColors.careGreen,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}

class _AdoptionTeaserCard extends StatelessWidget {
  const _AdoptionTeaserCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;

    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        key: const Key('home-adoption-card'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                key: const Key('home-adoption-image'),
                height: 84,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.surfaceContainer,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/pets/home_adoption_golden.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  semanticLabel: 'Chó Golden đang tìm gia đình nhận nuôi',
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.pets_rounded,
                      color: AppColors.careGreen,
                      size: 36,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                key: const Key('home-adoption-title'),
                'Tìm nhà cho Golden',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.captionStrong(),
              ),
              const SizedBox(height: 4),
              Text(
                key: const Key('home-adoption-meta'),
                '2 tháng tuổi • Hiền lành',
                maxLines: usesExpandedTextLayout ? null : 1,
                overflow: usesExpandedTextLayout ? null : TextOverflow.ellipsis,
                style: AppTextStyles.micro(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              if (usesExpandedTextLayout)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      key: const Key('home-adoption-cta'),
                      'NHẬN NUÔI',
                      style: AppTextStyles.micro(),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      key: const Key('home-adoption-view-more'),
                      'Xem thêm',
                      style: AppTextStyles.micro(color: AppColors.primary500),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        key: const Key('home-adoption-cta'),
                        'NHẬN NUÔI',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.micro(),
                      ),
                    ),
                    Text(
                      key: const Key('home-adoption-view-more'),
                      'Xem thêm',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.micro(color: AppColors.primary500),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetListHeader extends StatelessWidget {
  const _PetListHeader({
    required this.onOpenNotifications,
    required this.onOpenSearch,
  });

  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;
    final title = Text(
      'PawMate',
      maxLines: usesExpandedTextLayout ? null : 1,
      overflow: usesExpandedTextLayout ? null : TextOverflow.ellipsis,
      style: AppTextStyles.h2(color: AppColors.primary700),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Thông báo',
          onPressed: onOpenNotifications,
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        IconButton(
          tooltip: 'Tìm thú cưng',
          onPressed: onOpenSearch,
          icon: const Icon(Icons.search_rounded),
        ),
      ],
    );
    final identity = Row(
      children: [
        const CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.careGreenSoft,
          child: Icon(
            Icons.person_rounded,
            color: AppColors.careGreen,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: title),
      ],
    );
    if (usesExpandedTextLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          identity,
          const SizedBox(height: AppSpacing.s8),
          Align(alignment: Alignment.centerRight, child: actions),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: identity),
        actions,
      ],
    );
  }
}

class _FeaturedPetCard extends StatelessWidget {
  const _FeaturedPetCard({
    required this.pet,
    required this.now,
    required this.onTap,
  });

  final PetProfile pet;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _petStatusColor(context, pet.healthStatus);
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        key: Key('pet-list-featured-${pet.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 192,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PetAvatarMedia(
                      key: Key('pet-list-avatar-${pet.id}'),
                      source: pet.avatarPath,
                      semanticLabel: 'Ảnh của ${pet.name}',
                      fallback: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _petHeroGradient(pet),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            pet.species == 'cat'
                                ? Icons.cruelty_free_rounded
                                : Icons.pets_rounded,
                            color: Colors.white.withValues(alpha: 0.92),
                            size: 78,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      top: 18,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: AppShadows.soft,
                        ),
                        child: Text(
                          pet.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.captionStrong().copyWith(
                            color: AppColors.primary700,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (usesExpandedTextLayout)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pet.name, style: AppTextStyles.h3()),
                          const SizedBox(height: 2),
                          Text(
                            '${_petBreedSummary(pet)} • ${_petAgeLabel(pet.dateOfBirth, now)}',
                            style: AppTextStyles.body(),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: _PetStatusChip(
                              label: _petHealthLabel(pet.healthStatus),
                              color: statusColor,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pet.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.h3(),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_petBreedSummary(pet)} • ${_petAgeLabel(pet.dateOfBirth, now)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.body(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _PetStatusChip(
                            label: _petHealthLabel(pet.healthStatus),
                            color: statusColor,
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _PetInfoPill(
                          icon: Icons.vaccines_outlined,
                          label: pet.healthStatus == 'needs_vaccine'
                              ? 'Cần tiêm phòng'
                              : 'Đã tiêm phòng',
                        ),
                        _PetInfoPill(
                          icon: Icons.calendar_month_outlined,
                          label: 'Lịch hẹn: 20/05',
                          accent: AppColors.primary500,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetGridCard extends StatelessWidget {
  const _PetGridCard({
    required this.pet,
    required this.now,
    required this.onTap,
  });

  final PetProfile pet;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        key: Key('pet-list-card-${pet.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: AspectRatio(
                  aspectRatio: 167 / 130,
                  child: PetAvatarMedia(
                    key: Key('pet-list-avatar-${pet.id}'),
                    source: pet.avatarPath,
                    semanticLabel: 'Ảnh của ${pet.name}',
                    fallback: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _petHeroGradient(pet),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          pet.species == 'cat'
                              ? Icons.cruelty_free_rounded
                              : Icons.pets_rounded,
                          color: Colors.white.withValues(alpha: 0.92),
                          size: 42,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.name,
                      maxLines: usesExpandedTextLayout ? null : 1,
                      overflow: usesExpandedTextLayout
                          ? null
                          : TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_petSpeciesLabel(pet.species)} • ${_petAgeLabel(pet.dateOfBirth, now)}',
                      maxLines: usesExpandedTextLayout ? null : 1,
                      overflow: usesExpandedTextLayout
                          ? null
                          : TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetListAddCard extends StatelessWidget {
  const _PetListAddCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final visualHeight = constraints.constrainHeight(
          constraints.maxWidth + 5,
        );
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: double.infinity,
            height: visualHeight,
            child: Material(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: InkWell(
                key: const Key('pet-list-add-card'),
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.9),
                      width: 1.4,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: AppControlSize.minTouchTarget,
                        height: AppControlSize.minTouchTarget,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: AppShadows.soft,
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: AppColors.primary700,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Thêm thú cưng',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.label().copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyPetListState extends StatelessWidget {
  const _EmptyPetListState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 28),
      child: Column(
        children: [
          const _PetEmptyHeader(),
          const SizedBox(height: 36),
          Image.asset(
            'assets/images/pets/empty_first_pet.png',
            key: const Key('pet-list-empty-illustration'),
            width: 280,
            height: 280,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 24),
          Text(
            'Thêm thú cưng đầu tiên',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppColors.primary500,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          const _PetEmptyBenefit(label: 'Theo dõi lịch tiêm phòng & sức khỏe'),
          const SizedBox(height: 16),
          const _PetEmptyBenefit(label: 'Nhận cảnh báo cứu hộ kịp thời'),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              key: const Key('pet-list-empty-create-button'),
              onPressed: onCreate,
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Thêm hồ sơ thú cưng'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PetEmptyHeader extends StatelessWidget {
  const _PetEmptyHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.pets_rounded, color: AppColors.primary700, size: 28),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'PawMate',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.primary700,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Thông báo',
          onPressed: () => context.go('/notifications'),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _PetEmptyBenefit extends StatelessWidget {
  const _PetEmptyBenefit({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.successSoft,
            child: Icon(
              Icons.check_rounded,
              size: 17,
              color: AppColors.careGreenStrong,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PetStatusChip extends StatelessWidget {
  const _PetStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: usesExpandedTextLayout
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, size: 16, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.captionStrong().copyWith(
                    color: color,
                    height: 1,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.captionStrong().copyWith(
                    color: color,
                    height: 1,
                  ),
                ),
              ],
            ),
    );
  }
}

class _PetInfoPill extends StatelessWidget {
  const _PetInfoPill({
    required this.icon,
    required this.label,
    this.accent = AppColors.careGreen,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label().copyWith(color: accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _PetSyncBanner extends StatelessWidget {
  const _PetSyncBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.sync_problem_rounded, color: colorScheme.error),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _PetSyncError extends StatelessWidget {
  const _PetSyncError({
    required this.error,
    required this.message,
    required this.onRetry,
  });

  final Object error;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PawMateStateView(
      key: const Key('pet-list-error-state'),
      type:
          error is PetApiException &&
              (error as PetApiException).statusCode != null
          ? PawMateStateType.error
          : PawMateStateType.offline,
      title: 'Không tải được dữ liệu',
      message: message,
      primaryActionLabel: 'Thử lại',
      onPrimaryAction: onRetry,
    );
  }
}

class _PetListLoadingState extends StatelessWidget {
  const _PetListLoadingState();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('pet-list-loading-state'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PawMateSkeleton(width: 44, height: 44, circular: true),
              const SizedBox(width: 12),
              const PawMateSkeleton(width: 128, height: 28),
              const Spacer(),
              const PawMateSkeleton(width: 40, height: 40, circular: true),
              const SizedBox(width: 8),
              const PawMateSkeleton(width: 40, height: 40, circular: true),
            ],
          ),
          const SizedBox(height: 34),
          const PawMateSkeleton(width: 270, height: 32),
          const SizedBox(height: 10),
          const PawMateSkeleton(width: 220, height: 20),
          const SizedBox(height: 26),
          const PawMateSkeleton(
            width: double.infinity,
            height: 398,
            borderRadius: 24,
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(
                child: PawMateSkeleton(
                  width: double.infinity,
                  height: 210,
                  borderRadius: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: PawMateSkeleton(
                  width: double.infinity,
                  height: 210,
                  borderRadius: 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

List<Color> _petHeroGradient(PetProfile pet) {
  if (pet.species == 'cat') {
    return const [AppColors.brown, AppColors.mint];
  }
  return const [AppColors.mint, AppColors.deepGreen];
}

void _openPetForm(BuildContext context, {required String returnTo}) {
  context.push(
    Uri(
      path: '/pets/create',
      queryParameters: {'returnTo': returnTo},
    ).toString(),
  );
}

String _petSpeciesLabel(String species) {
  switch (species) {
    case 'dog':
      return 'Chó';
    case 'cat':
      return 'Mèo';
    default:
      return 'Khác';
  }
}

String _petAgeLabel(DateTime? dateOfBirth, DateTime now) {
  if (dateOfBirth == null) {
    return 'Chưa cập nhật tuổi';
  }
  var years = now.year - dateOfBirth.year;
  final hasBirthdayPassed =
      now.month > dateOfBirth.month ||
      (now.month == dateOfBirth.month && now.day >= dateOfBirth.day);
  if (!hasBirthdayPassed) {
    years -= 1;
  }

  if (years <= 0) {
    final months =
        (now.year - dateOfBirth.year) * 12 + now.month - dateOfBirth.month;
    return '${months.clamp(1, 11)} tháng tuổi';
  }

  return '$years tuổi';
}

String _petBreedSummary(PetProfile pet) {
  final species = _petSpeciesLabel(pet.species).trim();
  final breed = pet.breed.trim();
  if (breed.isEmpty) {
    return species;
  }

  final normalizedSpecies = species.toLowerCase();
  final normalizedBreed = breed.toLowerCase();
  if (normalizedBreed == normalizedSpecies ||
      normalizedBreed.startsWith('$normalizedSpecies ')) {
    return breed;
  }

  return '$species $breed';
}

String _petHealthLabel(String healthStatus) {
  switch (healthStatus) {
    case 'needs_vaccine':
      return 'Cần tiêm';
    case 'monitoring':
      return 'Theo dõi';
    case 'chronic':
      return 'Bệnh mạn';
    case 'recovery':
      return 'Hồi phục';
    case 'healthy':
    case 'good':
      return 'Khỏe mạnh';
    default:
      return 'Theo dõi';
  }
}

Color _petStatusColor(BuildContext context, String healthStatus) {
  switch (healthStatus) {
    case 'needs_vaccine':
      return AppColors.primary500;
    case 'healthy':
    case 'good':
      return AppColors.careGreen;
    case 'chronic':
      return Theme.of(context).colorScheme.error;
    default:
      return AppColors.label;
  }
}

String _petSyncErrorMessage(Object error) {
  return 'Không thể đồng bộ hồ sơ thú cưng. Vui lòng thử lại.';
}
