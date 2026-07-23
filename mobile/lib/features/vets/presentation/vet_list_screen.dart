import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_navigation.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_bottom_nav.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../../core/widgets/pawmate_chip.dart';
import '../application/vet_finder_session_provider.dart';
import '../data/vet_api.dart';
import '../domain/vet_models.dart';

class VetListScreen extends ConsumerStatefulWidget {
  const VetListScreen({super.key});

  @override
  ConsumerState<VetListScreen> createState() => _VetListScreenState();
}

class _VetListScreenState extends ConsumerState<VetListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  VetSearchRequest? _activeRequest;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  Object? _loadError;
  bool _refreshQueued = false;
  int _requestSerial = 0;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    final finder = ref.read(vetFinderSessionProvider);
    _searchController.text = finder.query;
    _loadingInitial = !finder.hasDataset;
    if (finder.hasDataset) {
      _activeRequest = finder.buildSearchRequest();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncRequestIfNeeded();
        _restoreScrollOffset();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    if (_scrollController.hasClients) {
      ref
          .read(vetFinderSessionProvider.notifier)
          .rememberListScrollOffset(_scrollController.offset);
    }
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  VetSearchRequest _buildRequest({String? cursor}) {
    return ref
        .read(vetFinderSessionProvider)
        .buildSearchRequest(cursor: cursor);
  }

  void _handleScroll() {
    if (_scrollController.position.extentAfter < 240) {
      _loadMoreIfNeeded();
    }
  }

  void _queueRefresh() {
    if (_refreshQueued) {
      return;
    }

    _refreshQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshQueued = false;
      if (mounted) {
        _syncRequestIfNeeded();
      }
    });
  }

  void _syncRequestIfNeeded() {
    final request = _buildRequest();
    if (request == _activeRequest) {
      return;
    }

    _activeRequest = request;
    _loadPage(reset: true);
  }

  Future<void> _loadPage({required bool reset}) async {
    final finder = ref.read(vetFinderSessionProvider);
    final baseRequest = _activeRequest ?? finder.buildSearchRequest();
    final request = reset
        ? baseRequest
        : finder.buildSearchRequest(cursor: finder.nextCursor);
    final requestSerial = reset ? ++_requestSerial : _requestSerial;

    if (reset) {
      setState(() {
        _loadingInitial = true;
        _loadError = null;
      });
    } else {
      setState(() {
        _loadingMore = true;
      });
    }

    try {
      final result = await ref.read(vetApiProvider).search(request);
      if (!mounted || requestSerial != _requestSerial) {
        return;
      }

      setState(() {
        _loadError = null;
        _loadingInitial = false;
        _loadingMore = false;
      });
      if (reset) {
        ref
            .read(vetFinderSessionProvider.notifier)
            .storeDataset(
              items: result.items,
              total: result.total,
              nextCursor: result.nextCursor,
              source: VetFinderDatasetSource.search,
            );
      } else {
        ref.read(vetFinderSessionProvider.notifier).appendSearchPage(result);
      }
    } catch (error) {
      if (!mounted || requestSerial != _requestSerial) {
        return;
      }

      setState(() {
        _loadError = error;
        _loadingInitial = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMoreIfNeeded() async {
    final finder = ref.read(vetFinderSessionProvider);
    if (_loadingInitial || _loadingMore || finder.nextCursor == null) {
      return;
    }

    await _loadPage(reset: false);
  }

  Future<void> _refresh() async {
    _activeRequest = _buildRequest();
    await _loadPage(reset: true);
  }

  List<PopupMenuEntry<String>> _buildFilterMenuItems(List<String> cities) {
    final finder = ref.read(vetFinderSessionProvider);
    return [
      const PopupMenuItem<String>(
        value: 'sort:curated',
        child: Text('Ưu tiên PawMate'),
      ),
      const PopupMenuItem<String>(
        value: 'sort:ratingDesc',
        child: Text('Đánh giá cao'),
      ),
      const PopupMenuItem<String>(
        value: 'sort:nameAsc',
        child: Text('Tên A-Z'),
      ),
      PopupMenuItem<String>(
        value: 'rating4',
        child: Text(finder.rating4Plus ? 'Bỏ lọc đánh giá 4+' : 'Đánh giá 4+'),
      ),
      for (final city in cities)
        PopupMenuItem<String>(value: 'city:$city', child: Text(city)),
    ];
  }

  void _handleFilterMenuSelection(String value) {
    final notifier = ref.read(vetFinderSessionProvider.notifier);
    switch (value) {
      case 'sort:curated':
        notifier.setSort(VetSortOption.curated);
      case 'sort:ratingDesc':
        notifier.setSort(VetSortOption.ratingDesc);
      case 'sort:nameAsc':
        notifier.setSort(VetSortOption.nameAsc);
      case 'rating4':
        notifier.toggleRating4Plus();
      default:
        if (value.startsWith('city:')) {
          notifier.setCity(value.substring('city:'.length));
        }
    }
    _queueRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final finder = ref.watch(vetFinderSessionProvider);
    final items = finder.items;
    const cities = [
      'Tất cả',
      'Hà Nội',
      'TP Hồ Chí Minh',
      'Hải Phòng',
      'Đà Nẵng',
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.raised,
        ),
        child: FloatingActionButton(
          heroTag: 'vet-list-map-fab',
          backgroundColor: AppColors.primary500,
          foregroundColor: Colors.white,
          elevation: 0,
          highlightElevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          onPressed: _openMap,
          child: const Icon(Icons.add_location_alt_outlined, size: 28),
        ),
      ),
      bottomNavigationBar: const PawMateBottomNav(currentRoute: '/vets/list'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 128),
            children: [
              _VetListHeader(
                onBack: () => PawMateNavigation.backOrGo(context, '/vets/map'),
              ),
              const SizedBox(height: AppSpacing.s12),
              _VetSearchField(
                controller: _searchController,
                onChanged: _handleSearchChanged,
                onFilterSelected: _handleFilterMenuSelection,
                filterItems: _buildFilterMenuItems(cities),
              ),
              const SizedBox(height: AppSpacing.s12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Gần nhất',
                      selected:
                          finder.sort == VetSortOption.curated &&
                          finder.selectedCity == 'Tất cả' &&
                          !finder.only24h &&
                          !finder.openNow &&
                          !finder.rating4Plus,
                      onSelected: () {
                        ref
                            .read(vetFinderSessionProvider.notifier)
                            .resetFilters();
                        _searchController.clear();
                        _queueRefresh();
                      },
                    ),
                    const SizedBox(width: 12),
                    _FilterChip(
                      label: '24/7',
                      selected: finder.only24h,
                      onSelected: () {
                        ref
                            .read(vetFinderSessionProvider.notifier)
                            .toggleOnly24h();
                        _queueRefresh();
                      },
                    ),
                    const SizedBox(width: 12),
                    _FilterChip(
                      label: 'Đang mở',
                      selected: finder.openNow,
                      onSelected: () {
                        ref
                            .read(vetFinderSessionProvider.notifier)
                            .toggleOpenNow();
                        _queueRefresh();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              _MiniMapPreview(total: finder.total, onTap: _openMap),
              const SizedBox(height: AppSpacing.s12),
              _LocationPrompt(
                city: finder.selectedCity == 'Tất cả'
                    ? 'Quận 1'
                    : finder.selectedCity,
                onSettingsTap: () => _showPlaceholder(
                  context,
                  'Quyền vị trí sẽ nối với thiết lập hệ thống ở bước tích hợp.',
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              _ResultsHeader(
                total: finder.total,
                subtitle: finder.selectedCity == 'Tất cả'
                    ? 'Tìm thấy phòng khám phù hợp'
                    : 'Lọc trong ${finder.selectedCity}',
              ),
              const SizedBox(height: AppSpacing.s12),
              if (_loadingInitial)
                const _VetInfoCard(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                )
              else if (_loadError != null && !finder.hasDataset)
                _VetInfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Không tải được danh sách phòng khám',
                        style: AppTextStyles.h4(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _loadError.toString(),
                        style: AppTextStyles.bodyCompact(),
                      ),
                      const SizedBox(height: 16),
                      PawMateButton(
                        key: const Key('vet-list-retry-button'),
                        label: 'Thử lại',
                        fullWidth: false,
                        variant: PawMateButtonVariant.secondary,
                        onPressed: () => _loadPage(reset: true),
                      ),
                    ],
                  ),
                )
              else if (items.isEmpty)
                _VetInfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chưa có phòng khám phù hợp',
                        style: AppTextStyles.h4(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Thử đổi từ khóa, nới bộ lọc hoặc chuyển sang khu vực khác để tiếp tục tìm kiếm.',
                        style: AppTextStyles.bodyCompact(),
                      ),
                    ],
                  ),
                )
              else ...[
                if (_loadError != null)
                  _VetInfoCard(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Không làm mới được dữ liệu. Đang hiển thị kết quả gần nhất.',
                            style: AppTextStyles.bodyCompact(),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _loadPage(reset: true),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(
                              72,
                              AppControlSize.minTouchTarget,
                            ),
                          ),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _VetCard(
                      vet: items[i],
                      featured: i == 1,
                      onTap: () {
                        ref
                            .read(vetFinderSessionProvider.notifier)
                            .selectVet(items[i].vetId);
                        context.push(
                          Uri(
                            path: '/vets/${items[i].vetId}',
                            queryParameters: const {'returnTo': '/vets/list'},
                          ).toString(),
                        );
                      },
                    ),
                  ),
                if (_loadingMore)
                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (finder.nextCursor != null && !_loadingMore)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Center(
                      child: PawMateButton(
                        label: 'Xem thêm',
                        fullWidth: false,
                        variant: PawMateButtonVariant.secondary,
                        onPressed: _loadMoreIfNeeded,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleSearchChanged(String value) {
    ref.read(vetFinderSessionProvider.notifier).setQuery(value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) {
        _queueRefresh();
      }
    });
  }

  void _restoreScrollOffset() {
    final offset = ref.read(vetFinderSessionProvider).listScrollOffset;
    if (!_scrollController.hasClients || offset <= 0) {
      return;
    }
    final maxOffset = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(offset.clamp(0, maxOffset).toDouble());
  }

  void _openMap() {
    if (_scrollController.hasClients) {
      ref
          .read(vetFinderSessionProvider.notifier)
          .rememberListScrollOffset(_scrollController.offset);
    }
    PawMateNavigation.backOrGo(context, '/vets/map');
  }

  static void _showPlaceholder(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _VetListHeader extends StatelessWidget {
  const _VetListHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 28),
              tooltip: 'Quay lại',
            ),
          ),
          Text('PawMate', style: AppTextStyles.h2(color: AppColors.primary700)),
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              image: true,
              label: 'Ảnh đại diện thú cưng Kem',
              child: Container(
                width: 48,
                height: 48,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 2),
                  color: AppColors.careGreenSoft,
                ),
                child: Image.asset(
                  'assets/images/pets/p1_05_kem.png',
                  fit: BoxFit.cover,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded || frame != null) {
                          return child;
                        }
                        return const Icon(
                          Icons.pets_rounded,
                          color: AppColors.deepGreen,
                          size: 24,
                        );
                      },
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.pets_rounded,
                    color: AppColors.deepGreen,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VetSearchField extends StatelessWidget {
  const _VetSearchField({
    required this.controller,
    required this.onChanged,
    required this.onFilterSelected,
    required this.filterItems,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onFilterSelected;
  final List<PopupMenuEntry<String>> filterItems;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.primary500, width: 2),
      ),
      padding: const EdgeInsets.only(left: 16, right: 4),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: AppColors.primary500,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: const Key('vet-list-search-field'),
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Tìm kiếm thú y...',
                contentPadding: EdgeInsets.zero,
              ),
              style: AppTextStyles.field(),
            ),
          ),
          PopupMenuButton<String>(
            key: const Key('vet-list-filter-menu'),
            tooltip: 'Bộ lọc phòng khám',
            onSelected: onFilterSelected,
            itemBuilder: (_) => filterItems,
            icon: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary500,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: const Icon(Icons.tune_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMapPreview extends StatelessWidget {
  const _MiniMapPreview({required this.total, required this.onTap});

  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: onTap,
        child: Ink(
          height: 130,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadows.soft,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _MiniMapPainter()),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.36),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.24),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 22,
                  bottom: 24,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.map_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Xem trên bản đồ',
                        style: AppTextStyles.label(color: Colors.white)
                            .copyWith(
                              shadows: const [
                                Shadow(
                                  color: Colors.black38,
                                  offset: Offset(0, 1),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 18,
                  bottom: 22,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '$total Phòng khám',
                      style: AppTextStyles.captionStrong(
                        color: AppColors.primary700,
                      ),
                    ),
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

class _MiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = AppColors.lightBeige;
    canvas.drawRect(Offset.zero & size, background);

    final river = Paint()
      ..color = AppColors.mint
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke;
    final riverPath = Path()
      ..moveTo(size.width * 0.12, size.height * 0.18)
      ..cubicTo(
        size.width * 0.36,
        size.height * 0.44,
        size.width * 0.48,
        size.height * 0.30,
        size.width * 0.66,
        size.height * 0.70,
      )
      ..cubicTo(
        size.width * 0.74,
        size.height * 0.86,
        size.width * 0.92,
        size.height * 0.70,
        size.width,
        size.height * 0.86,
      );
    canvas.drawPath(riverPath, river);

    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 3;
    for (var x = -20.0; x < size.width; x += 54) {
      canvas.drawLine(Offset(x, 0), Offset(x + 88, size.height), road);
    }
    for (var y = 12.0; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 18), road);
    }

    void pin(Offset center, double radius, Color color) {
      final paint = Paint()..color = color;
      canvas.drawCircle(center, radius, paint);
      canvas.drawCircle(center, radius * 0.38, Paint()..color = Colors.white);
    }

    pin(
      Offset(size.width * 0.40, size.height * 0.42),
      10,
      AppColors.primary500,
    );
    pin(Offset(size.width * 0.55, size.height * 0.32), 8, AppColors.primary500);
    pin(Offset(size.width * 0.63, size.height * 0.58), 7, AppColors.primary500);
    pin(Offset(size.width * 0.48, size.height * 0.76), 6, AppColors.brown);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LocationPrompt extends StatelessWidget {
  const _LocationPrompt({required this.city, required this.onSettingsTap});

  final String city;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.mint),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: AppColors.deepGreen,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đang cập nhật vị trí...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label(color: AppColors.deepGreen),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hiển thị các phòng khám tốt nhất gần bạn tại $city.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(color: AppColors.deepGreen),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onSettingsTap,
            style: TextButton.styleFrom(
              minimumSize: const Size(72, AppControlSize.minTouchTarget),
              textStyle: AppTextStyles.captionStrong(),
            ),
            child: const Text('CÀI ĐẶT'),
          ),
        ],
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.total, required this.subtitle});

  final int total;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('$total', style: AppTextStyles.h1(color: AppColors.primary500)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KẾT QUẢ', style: AppTextStyles.h3()),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.captionStrong(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VetCard extends StatelessWidget {
  const _VetCard({
    required this.vet,
    required this.featured,
    required this.onTap,
  });

  final VetSummary vet;
  final bool featured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const titleColor = AppColors.textPrimary;
    const subtitleColor = AppColors.textSecondary;
    final chips = vet.displayServices.take(2).toList();
    final isCompact =
        MediaQuery.sizeOf(context).width < 430 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.15;
    final ratingBadge = _Badge(
      label: vet.averageRating != null
          ? '★ ${vet.averageRating!.toStringAsFixed(1)}'
          : 'Top #${vet.seedRank}',
      background: AppColors.tertiarySoft,
      textColor: AppColors.primary700,
      compact: isCompact,
    );
    final distance = vet.distanceLabel ?? '1.2 km';

    return Semantics(
      button: true,
      label: 'Mở ${vet.name}',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.soft,
          ),
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 12 : 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _VetThumbnail(vet: vet, featured: featured, compact: isCompact),
                SizedBox(width: isCompact ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              vet.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.h4(color: titleColor),
                            ),
                          ),
                          if (!isCompact) ...[
                            const SizedBox(width: 10),
                            ratingBadge,
                          ],
                        ],
                      ),
                      if (isCompact) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ratingBadge,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        vet.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.captionStrong(
                          color: subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              vet.statusLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.captionStrong(
                                color: AppColors.success,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            distance,
                            style: AppTextStyles.captionStrong(
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < chips.length; i++)
                            _Badge(
                              label: chips[i],
                              background: i == 0
                                  ? AppColors.primarySoft
                                  : AppColors.surfaceMuted,
                              textColor: i == 0
                                  ? AppColors.primary700
                                  : AppColors.deepGreen,
                              compact: isCompact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: subtitleColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${vet.city} • ${vet.district}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption(
                                color: subtitleColor,
                              ),
                            ),
                          ),
                          if (!isCompact) ...[
                            const SizedBox(width: 10),
                            Text(
                              '(${vet.reviewCount} đánh giá)',
                              style: AppTextStyles.caption(
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (isCompact)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '(${vet.reviewCount} đánh giá)',
                            style: AppTextStyles.caption(color: subtitleColor),
                          ),
                        ),
                    ],
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

class _VetThumbnail extends StatelessWidget {
  const _VetThumbnail({
    required this.vet,
    required this.featured,
    required this.compact,
  });

  final VetSummary vet;
  final bool featured;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 78.0 : 86.0;
    final iconSize = compact ? 30.0 : 34.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: featured
              ? const [AppColors.surface, AppColors.mint]
              : const [AppColors.lightBeige, AppColors.deepGreen],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.local_hospital_outlined,
            size: iconSize,
            color: featured ? AppColors.deepGreen : AppColors.surface,
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: AppColors.primary500,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.pets_rounded,
                size: 11,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return PawMateChip(
      label: label,
      selected: selected,
      onPressed: onSelected,
      variant: PawMateChipVariant.filter,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.textColor,
    this.compact = false,
  });

  final String label;
  final Color background;
  final Color textColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.micro(color: textColor),
      ),
    );
  }
}

class _VetInfoCard extends StatelessWidget {
  const _VetInfoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: child,
    );
  }
}
