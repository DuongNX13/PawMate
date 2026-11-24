import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_navigation.dart';
import '../../app/theme/app_tokens.dart';

class PawMateBottomNav extends StatelessWidget {
  const PawMateBottomNav({
    super.key,
    required this.currentRoute,
    this.onDestinationSelected,
  });

  final String currentRoute;
  final ValueChanged<String>? onDestinationSelected;

  static const destinations = <PawMateBottomNavDestination>[
    PawMateBottomNavDestination(
      label: 'Home',
      iconAsset: 'assets/icons/navigation/home.png',
      route: '/pets',
      activePrefix: '/pets',
    ),
    PawMateBottomNavDestination(
      label: 'Vet',
      iconAsset: 'assets/icons/navigation/vet.png',
      route: '/vets/map',
      activePrefix: '/vets',
    ),
    PawMateBottomNavDestination(
      label: 'Health',
      iconAsset: 'assets/icons/navigation/health.png',
      route: '/health',
      activePrefix: '/health',
    ),
    PawMateBottomNavDestination(
      label: 'Rescue',
      iconAsset: 'assets/icons/navigation/rescue.png',
      route: '/rescue',
      activePrefix: '/rescue',
    ),
    PawMateBottomNavDestination(
      label: 'Profile',
      iconAsset: 'assets/icons/navigation/profile.png',
      route: '/profile',
      activePrefix: '/profile',
    ),
  ];

  // Figma v0.34 locks an icon-only bar (LOCKED/NAV/v0.33/ICON_ONLY): text
  // scale cannot change its height. Names reach assistive tech through
  // semantics labels and long-press tooltips.
  @override
  Widget build(BuildContext context) {
    const navigationHeight = AppControlSize.bottomNavHeight;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.navShell),
        ),
        boxShadow: AppShadows.soft,
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: SizedBox(
          height: navigationHeight,
          child: Row(
            children: destinations.map((item) {
              final isActive = item.isActive(currentRoute);

              return Expanded(
                child: Semantics(
                  button: true,
                  selected: isActive,
                  label: item.label,
                  onTap: () => _select(context, item.route),
                  child: ExcludeSemantics(
                    child: Tooltip(
                      message: item.label,
                      excludeFromSemantics: true,
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: InkWell(
                          onTap: () => _select(context, item.route),
                          borderRadius: BorderRadius.circular(
                            AppRadius.navActive,
                          ),
                          child: AnimatedContainer(
                            duration: AppMotion.standard,
                            curve: AppMotion.standardCurve,
                            height: navigationHeight - 2,
                            margin: const EdgeInsets.symmetric(vertical: 1),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s4,
                              vertical: AppSpacing.s4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.navActive
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                AppRadius.navActive,
                              ),
                            ),
                            child: Center(
                              child: ImageIcon(
                                AssetImage(item.iconAsset),
                                size: AppControlSize.bottomNavIcon,
                                color: isActive
                                    ? AppColors.white
                                    : AppColors.navInactiveIcon,
                              ),
                            ),
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
      ),
    );
  }

  void _select(BuildContext context, String route) {
    final callback = onDestinationSelected;
    if (callback != null) {
      callback(route);
      return;
    }
    final navigationScope = PawMateNavigationScope.maybeOf(context);
    if (navigationScope != null) {
      navigationScope.selectShellLocation(
        route,
        scrollContext: context,
        currentLocation: currentRoute,
      );
      return;
    }
    context.go(route);
  }
}

class PawMateBottomNavDestination {
  const PawMateBottomNavDestination({
    required this.label,
    required this.iconAsset,
    required this.route,
    required this.activePrefix,
  });

  final String label;
  final String iconAsset;
  final String route;
  final String activePrefix;

  bool isActive(String currentRoute) {
    return currentRoute == route ||
        currentRoute == activePrefix ||
        currentRoute.startsWith('$activePrefix/');
  }
}
