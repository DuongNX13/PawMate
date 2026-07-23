import 'package:flutter/material.dart';

import 'pawmate_bottom_nav.dart';
import 'pawmate_fixed_cta_bar.dart';
import 'pawmate_top_bar.dart';

enum PawMateSafeAreaPolicy {
  /// Protect all system insets. Use for full-screen content without app bars.
  all,

  /// Protect top only when there is no top bar and bottom only when there is
  /// no footer. Horizontal cutouts are always protected.
  automatic,

  /// Draw edge-to-edge. The caller owns all system-inset handling.
  none,
}

class PawMatePageScaffold extends StatelessWidget {
  const PawMatePageScaffold({
    super.key,
    required this.body,
    this.topBar,
    this.bottomNavCurrentRoute,
    this.bottomNavigationBar,
    this.fixedCtaBar,
    this.safeAreaPolicy = PawMateSafeAreaPolicy.automatic,
    @Deprecated('Use safeAreaPolicy instead.') this.safeBody = false,
    this.bodyPadding = EdgeInsets.zero,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = false,
    this.floatingActionButton,
  }) : assert(
         bottomNavCurrentRoute == null || bottomNavigationBar == null,
         'Use bottomNavCurrentRoute or bottomNavigationBar, not both.',
       );

  final Widget body;
  final PawMateTopBar? topBar;
  final String? bottomNavCurrentRoute;
  final Widget? bottomNavigationBar;
  final PawMateFixedCtaBar? fixedCtaBar;
  final PawMateSafeAreaPolicy safeAreaPolicy;

  @Deprecated('Use safeAreaPolicy instead.')
  final bool safeBody;
  final EdgeInsetsGeometry bodyPadding;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final bool extendBody;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final nav =
        bottomNavigationBar ??
        (bottomNavCurrentRoute == null
            ? null
            : PawMateBottomNav(currentRoute: bottomNavCurrentRoute!));
    final footer = switch ((fixedCtaBar, nav)) {
      (final PawMateFixedCtaBar cta, final Widget bottomNav) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [cta, bottomNav],
      ),
      (final PawMateFixedCtaBar cta, null) => cta,
      (null, final Widget bottomNav) => bottomNav,
      (null, null) => null,
    };
    Widget content = Padding(padding: bodyPadding, child: body);
    final effectiveSafeArea = safeBody
        ? PawMateSafeAreaPolicy.all
        : safeAreaPolicy;
    content = switch (effectiveSafeArea) {
      PawMateSafeAreaPolicy.all => SafeArea(child: content),
      PawMateSafeAreaPolicy.automatic => SafeArea(
        top: topBar == null,
        bottom: footer == null,
        child: content,
      ),
      PawMateSafeAreaPolicy.none => content,
    };

    return Scaffold(
      backgroundColor:
          backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
      appBar: topBar,
      body: content,
      bottomNavigationBar: footer,
      floatingActionButton: floatingActionButton,
    );
  }
}
