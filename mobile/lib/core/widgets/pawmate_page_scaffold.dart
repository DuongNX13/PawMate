import 'package:flutter/material.dart';

import 'pawmate_bottom_nav.dart';
import 'pawmate_fixed_cta_bar.dart';
import 'pawmate_layout.dart';
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

enum PawMatePageLayoutMode {
  /// Main destinations and important dynamic details. The composition can use
  /// the available width up to the product-wide content ceiling.
  fullResponsive,

  /// Supporting flows retain their relative composition inside the canonical
  /// mobile design width while remaining scroll/IME safe in the screen body.
  proportional,

  /// Edge-to-edge maps/media own their width contract.
  edgeToEdge,
}

class PawMatePageScaffold extends StatelessWidget {
  const PawMatePageScaffold({
    super.key,
    required this.body,
    this.topBar,
    this.bottomNavCurrentRoute,
    this.bottomNavigationBar,
    this.fixedCtaBar,
    this.fixedFooter,
    this.safeAreaPolicy = PawMateSafeAreaPolicy.automatic,
    @Deprecated('Use safeAreaPolicy instead.') this.safeBody = false,
    this.bodyPadding = EdgeInsets.zero,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = false,
    this.floatingActionButton,
    this.showBrandTexture = true,
    this.layoutMode = PawMatePageLayoutMode.proportional,
  }) : assert(
         bottomNavCurrentRoute == null || bottomNavigationBar == null,
         'Use bottomNavCurrentRoute or bottomNavigationBar, not both.',
       );

  final Widget body;
  final PawMateTopBar? topBar;
  final String? bottomNavCurrentRoute;
  final Widget? bottomNavigationBar;
  final PawMateFixedCtaBar? fixedCtaBar;
  final Widget? fixedFooter;
  final PawMateSafeAreaPolicy safeAreaPolicy;

  @Deprecated('Use safeAreaPolicy instead.')
  final bool safeBody;
  final EdgeInsetsGeometry bodyPadding;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final bool extendBody;
  final Widget? floatingActionButton;
  final bool showBrandTexture;
  final PawMatePageLayoutMode layoutMode;

  @override
  Widget build(BuildContext context) {
    final nav =
        bottomNavigationBar ??
        (bottomNavCurrentRoute == null
            ? null
            : PawMateBottomNav(currentRoute: bottomNavCurrentRoute!));
    final rawFooterContent = fixedFooter ?? fixedCtaBar;
    // When a PawMate CTA sits above the code-owned bottom navigation, the nav
    // is the only surface touching the physical bottom edge and therefore the
    // only owner of the home-indicator inset. Removing padding from the CTA's
    // MediaQuery prevents a duplicate blank band without changing nav geometry.
    final footerContent =
        fixedFooter == null && fixedCtaBar != null && nav != null
        ? MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: fixedCtaBar!,
          )
        : rawFooterContent;
    final footer = switch ((footerContent, nav)) {
      (final Widget cta, final Widget bottomNav) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [cta, bottomNav],
      ),
      (final Widget cta, null) => cta,
      (null, final Widget bottomNav) => bottomNav,
      (null, null) => null,
    };
    Widget pageBody = switch (layoutMode) {
      PawMatePageLayoutMode.fullResponsive => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: body,
        ),
      ),
      PawMatePageLayoutMode.proportional => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: body,
        ),
      ),
      PawMatePageLayoutMode.edgeToEdge => body,
    };
    Widget content = PawMateBrandCanvas(
      showTexture: showBrandTexture,
      child: Padding(padding: bodyPadding, child: pageBody),
    );
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
