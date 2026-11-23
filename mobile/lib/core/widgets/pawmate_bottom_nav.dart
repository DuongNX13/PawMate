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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final labelWidth = math.max(
          1.0,
          width / destinations.length - AppSpacing.s4 * 2,
        );
        var labelLines = 1;
        var labelHeight = 0.0;
        var captionMode = false;
        var captionHeight = 0.0;
        // Measure both weights so selecting a tab cannot change shell height.
        // Use the actual width/scaler; a scale threshold misses boundary fits.
        for (final item in destinations) {
          for (final style in [
            AppTextStyles.nav(),
            AppTextStyles.navActive(),
          ]) {
            final painter = TextPainter(
              text: TextSpan(text: item.label, style: style),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              locale: Localizations.maybeLocaleOf(context),
              textAlign: TextAlign.center,
            )..layout();
            captionMode |= painter.width > labelWidth;
            captionHeight = math.max(captionHeight, painter.height);
            painter.layout(maxWidth: labelWidth);
            labelLines = math.max(
              labelLines,
              painter.computeLineMetrics().length,
            );
            labelHeight = math.max(labelHeight, painter.height);
            painter.dispose();
          }
        }
        final navigationHeight = math.max(
          AppControlSize.bottomNavHeight,
          AppControlSize.bottomNavIcon +
              AppSpacing.s4 +
              labelHeight +
              AppSpacing.s4 * 2 +
              2,
        );
        // Keep the default-size anchor, including its fallback-font geometry.
        // In enlarged mode use only the space required for a 48dp+ icon target;
        // the caption must not needlessly steal map or form viewport height.
        captionMode &= MediaQuery.textScalerOf(context).scale(1) > 1;
        return _buildNavigation(
          context,
          captionMode ? AppControlSize.buttonHeight : navigationHeight,
          labelLines,
          captionMode ? captionHeight : null,
        );
      },
    );
  }

  Widget _buildNavigation(
    BuildContext context,
    double navigationHeight,
    int labelLines,
    double? captionHeight,
  ) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // At enlarged text sizes five full labels cannot fit five equal
            // slots. Keep the five 48dp+ destinations fixed, and show the current
            // destination unbroken above them. All controls retain full names.
            if (captionHeight != null)
              ExcludeSemantics(
                child: SizedBox(
                  height: captionHeight + AppSpacing.s8,
                  child: Center(
                    child: Text(
                      destinations
                          .firstWhere(
                            (d) => d.isActive(currentRoute),
                            orElse: () => destinations.first,
                          )
                          .label,
                      key: const Key('navigation-selected-caption'),
                      maxLines: 1,
                      style: AppTextStyles.navActive(
                        color: AppColors.navInactiveLabel,
                      ),
                    ),
                  ),
                ),
              ),
            SizedBox(
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
                                    if (captionHeight == null) ...[
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
                                  ],
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
          ],
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
