import 'package:flutter/material.dart';

import '../../core/widgets/pawmate_page_scaffold.dart';
import '../../core/widgets/pawmate_state_view.dart';
import '../../core/widgets/pawmate_top_bar.dart';
import 'app_navigation.dart';

class FeatureUnavailableScreen extends StatelessWidget {
  const FeatureUnavailableScreen({
    super.key,
    required this.title,
    required this.message,
    required this.fallbackLocation,
    this.bottomNavRoute,
  });

  final String title;
  final String message;
  final String fallbackLocation;
  final String? bottomNavRoute;

  @override
  Widget build(BuildContext context) {
    return PawMatePageScaffold(
      topBar: PawMateTopBar(
        title: title,
        showBackButton: true,
        onBack: () => PawMateNavigation.backOrGo(context, fallbackLocation),
      ),
      bottomNavCurrentRoute: bottomNavRoute,
      body: PawMateStateView(
        type: PawMateStateType.empty,
        title: title,
        message: message,
        primaryActionLabel: 'Quay lại',
        onPrimaryAction: () =>
            PawMateNavigation.backOrGo(context, fallbackLocation),
      ),
    );
  }
}
