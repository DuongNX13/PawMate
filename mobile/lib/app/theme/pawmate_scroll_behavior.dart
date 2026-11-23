import 'package:flutter/material.dart';

/// Keeps PawMate scrolling native while opting out of Material's visual
/// overscroll decorators.
///
/// The decorators are cosmetic only. In the current Windows Android build
/// lane, Flutter's bundled Material stretch shader is absent from the APK and
/// causes an unhandled runtime exception when an Android scroll view reaches
/// its edge. Returning the child preserves scrolling, drag devices and
/// semantics without taking that broken shader path.
class PawMateScrollBehavior extends MaterialScrollBehavior {
  const PawMateScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
