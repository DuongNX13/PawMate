import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_bottom_nav.dart';
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

  String _selectedCity = 'Tất cả';
  bool _only24h = false;
  bool _openNow = false;
  bool _rating4Plus = false;
  VetSortOption _sort = VetSortOption.curated;

  VetSearchRequest? _activeRequest;
  List<VetSummary> _items = const [];
  String? _nextCursor;
  int _total = 0;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  Object? _loadError;
  bool _refreshQueued = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncRequestIfNeeded();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  VetSearchRequest _buildRequest({String? cursor}) {
    return VetSearchRequest(
      keyword: _searchController.text.trim(),
      city: _selectedCity == 'Tất cả' ? null : _selectedCity,
      only24h: _only24h,
      openNow: _openNow,
      minRating: _rating4Plus ? 4 : null,
      sort: _sort,
      cursor: cursor,
    );
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
    final baseRequest = _activeRequest ?? _buildRequest();
    final request = reset ? baseRequest : _buildRequest(cursor: _nextCursor);

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
      if (!mounted) {
        return;
      }

      setState(() {
        _items = reset ? result.items : [..._items, ...result.items];
        _nextCursor = result.nextCursor;
        _total = result.total;
        _loadError = null;
        _loadingInitial = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadError = error;
        _loadingInitial = false;
        _loadingMore = false;
        if (reset) {
          _items = const [];
          _nextCursor = null;
          _total = 0;
        }
      });
    }
  }

  Future<void> _loadMoreIfNeeded() async {
    if (_loadingInitial || _loadingMore || _nextCursor == null) {
      return;
    }

    await _loadPage(reset: false);
  }

  Future<void> _refresh() async {
    _activeRequest = _buildRequest();
    await _loadPage(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heroLocation = _selectedCity == 'Tất cả'
        ? 'vị trí của bạn'
        : _selectedCity;
    const cities = [
      'Tất cả',
      'Hà Nội',
      'TP Hồ Chí Minh',
      'Hải Phòng',
      'Đà Nẵng',
    ];

    _queueRefreshIfStateChanged();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary500,
        foregroundColor: Colors.white,
        onPressed: () => context.go('/vets/map'),
        child: const Icon(Icons.map_outlined),
      ),
      bottomNavigationBar: const PawMateBottomNav(currentRoute: '/vets/list'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/pets'),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'PawMate',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.primary500,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _showPlaceholder(
                      context,
                      'Thông báo vet sẽ nối ở bước tiếp theo.',
                    ),
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Chăm sóc tốt nhất\ncho thú cưng của bạn.',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: AppColors.primary700,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$_total phòng khám gần $heroLocation.',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên phòng khám hoặc quận',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: PopupMenuButton<VetSortOption>(
                    onSelected: (value) => setState(() {
                      _sort = value;
                    }),
                    itemBuilder: (context) => VetSortOption.values
                        .map(
                          (option) => PopupMenuItem(
                            value: option,
                            child: Text(option.label),
                          ),
                        )
                        .toList(),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: cities.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final city = cities[index];
                    final isSelected = city == _selectedCity;

                    return ChoiceChip(
                      label: Text(city),
                      selected: isSelected,
                      onSelected: (_) => setState(() {
                        _selectedCity = city;
                      }),
                      showCheckmark: false,
                      selectedColor: const Color(0xFFFFEDD5),
                      labelStyle: theme.textTheme.labelLarge?.copyWith(
                        color: isSelected
                            ? const Color(0xFFC2410C)
                            : AppColors.secondary500,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.transparent
                            : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: '24h',
                      selected: _only24h,
                      onSelected: () => setState(() {
                        _only24h = !_only24h;
                      }),
                    ),
                    const SizedBox(width: 10),
                    _FilterChip(
                      label: 'Đang mở',
                      selected: _openNow,
                      onSelected: () => setState(() {
                        _openNow = !_openNow;
                      }),
                    ),
                    const SizedBox(width: 10),
                    _FilterChip(
                      label: 'Đánh giá 4+',
                      selected: _rating4Plus,
                      onSelected: () => setState(() {
                        _rating4Plus = !_rating4Plus;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'Sắp xếp: ${_sort.label}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$_total kết quả',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.secondary500,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_loadingInitial)
                const _VetInfoCard(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                )
              else if (_loadError != null)
                _VetInfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Không tải được danh sách phòng khám',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _loadError.toString(),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => _loadPage(reset: true),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              else if (_items.isEmpty)
                _VetInfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chưa có phòng khám phù hợp',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Thử đổi từ khóa, nới bộ lọc hoặc chuyển sang khu vực khác để tiếp tục tìm kiếm.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              else ...[
                for (var i = 0; i < _items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _VetCard(
                      vet: _items[i],
                      featured: i == 1,
                      onTap: () => context.go('/vets/${_items[i].id}'),
                    ),
                  ),
                if (_loadingMore)
                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_nextCursor != null && !_loadingMore)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Center(
                      child: OutlinedButton(
                        onPressed: _loadMoreIfNeeded,
                        child: const Text('Xem thêm'),
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

  void _queueRefreshIfStateChanged() {
    final request = _buildRequest();
    if (request != _activeRequest) {
      _queueRefresh();
    }
  }

  static void _showPlaceholder(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    final theme = Theme.of(context);
    final cardColor = featured ? const Color(0xFFA8C8F5) : AppColors.surface;
    final titleColor = featured
        ? const Color(0xFF204F7A)
        : AppColors.textPrimary;
    final subtitleColor = featured
        ? const Color(0xFF365E86)
        : AppColors.textSecondary;
    final chips = vet.displayServices.take(2).toList();

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.soft,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VetThumbnail(vet: vet, featured: featured),
              const SizedBox(width: 16),
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
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _Badge(
                          label: vet.averageRating != null
                              ? '★ ${vet.averageRating!.toStringAsFixed(1)}'
                              : 'Top #${vet.seedRank}',
                          background: AppColors.tertiarySoft,
                          textColor: const Color(0xFF7A6420),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      vet.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: subtitleColor,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var i = 0; i < chips.length; i++)
                          _Badge(
                            label: chips[i],
                            background: i == 0
                                ? AppColors.primarySoft
                                : const Color(0xFFF1F5F9),
                            textColor: i == 0
                                ? AppColors.primary700
                                : AppColors.secondary500,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: subtitleColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${vet.city} • ${vet.district}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: subtitleColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '(${vet.reviewCount} đánh giá)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: subtitleColor,
                            fontWeight: FontWeight.w500,
                          ),
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

class _VetThumbnail extends StatelessWidget {
  const _VetThumbnail({required this.vet, required this.featured});

  final VetSummary vet;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final icon = featured ? Icons.local_hospital_outlined : Icons.pets_rounded;
    final iconColor = featured ? AppColors.secondary500 : Colors.white;

    return Container(
      width: featured ? 92 : 104,
      height: featured ? 92 : 104,
      decoration: BoxDecoration(
        color: featured ? Colors.white : const Color(0xFF4CB7B6),
        shape: featured ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: featured ? null : BorderRadius.circular(18),
        boxShadow: featured ? AppShadows.soft : null,
      ),
      child: Icon(icon, size: featured ? 38 : 42, color: iconColor),
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
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      selectedColor: const Color(0xFFFFEDD5),
      backgroundColor: AppColors.surface,
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: selected ? const Color(0xFFC2410C) : AppColors.secondary500,
      ),
      side: BorderSide(color: selected ? Colors.transparent : AppColors.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.textColor,
  });

  final String label;
  final Color background;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: textColor),
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
        boxShadow: AppShadows.soft,
      ),
      child: child,
    );
  }
}
