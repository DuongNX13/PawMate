import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_tokens.dart';

class PawMateBottomNav extends StatelessWidget {
  const PawMateBottomNav({super.key, required this.currentRoute});

  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final items = <_BottomNavItem>[
      const _BottomNavItem(
        label: 'Thú cưng',
        icon: Icons.home_outlined,
        route: '/pets',
      ),
      const _BottomNavItem(
        label: 'Thú y',
        icon: Icons.travel_explore_outlined,
        route: '/vets/list',
      ),
      const _BottomNavItem(
        label: 'Sức khỏe',
        icon: Icons.favorite_border,
        route: '/health',
      ),
      const _BottomNavItem(
        label: 'Hồ sơ',
        icon: Icons.person_outline,
        route: '/profile',
      ),
    ];

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        decoration: const BoxDecoration(
          color: Color(0xE5FFFFFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: items.map((item) {
            final isActive = currentRoute == item.route;

            return Expanded(
              child: Semantics(
                button: true,
                selected: isActive,
                label: item.label,
                child: ExcludeSemantics(
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: InkWell(
                      onTap: isActive ? null : () => context.go(item.route),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        constraints: const BoxConstraints(minHeight: 52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFFFEDD5)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.icon,
                              size: 22,
                              color: isActive
                                  ? AppColors.primary700
                                  : AppColors.icon,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontFamily: 'Be Vietnam Pro',
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? AppColors.primary700
                                        : AppColors.icon,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _BottomNavItem {
  const _BottomNavItem({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}
