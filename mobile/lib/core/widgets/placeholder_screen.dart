import 'package:flutter/material.dart';

import 'pawmate_page_scaffold.dart';
import 'pawmate_state_view.dart';
import 'pawmate_top_bar.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.subtitle,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.bottomNavRoute,
  });

  final String title;
  final String subtitle;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? bottomNavRoute;

  @override
  Widget build(BuildContext context) {
    return PawMatePageScaffold(
      topBar: PawMateTopBar(title: title),
      bottomNavCurrentRoute: bottomNavRoute,
      body: PawMateStateView(
        type: PawMateStateType.empty,
        title: title,
        message: subtitle,
        primaryActionLabel: primaryActionLabel,
        onPrimaryAction: onPrimaryAction,
      ),
    );
  }
}
