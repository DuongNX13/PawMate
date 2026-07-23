import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_navigation.dart';
import '../../app/theme/app_text_styles.dart';
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

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final scaledLabelHeight =
        AppTextStyles.nav().fontSize! * AppTextStyles.nav().height! * textScale;
    final labelLines = textScale > 1.3 ? 2 : 1;
    final navigationHeight = math.max(
      AppControlSize.bottomNavHeight,
      AppControlSize.bottomNavIcon +
          AppSpacing.s4 +
          (scaledLabelHeight * labelLines) +
          (AppSpacing.s4 * 2) +
          2,
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ImageIcon(
                                AssetImage(item.iconAsset),
                                size: AppControlSize.bottomNavIcon,
                                color: isActive
                                    ? AppColors.white
                                    : AppColors.navInactiveIcon,
                              ),
                              const SizedBox(height: AppSpacing.s4),
                              Flexible(
                                child: Text(
                                  item.label,
                                  maxLines: labelLines,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: isActive
                                      ? AppTextStyles.navActive()
                                      : AppTextStyles.nav(),
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
