import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_route_registry.dart';

abstract final class PawMateNavigation {
  static void backOrGo(BuildContext context, String fallbackLocation) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(fallbackLocation);
  }

  static Page<void> adaptivePage({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
  }) {
    final restorationId = state.pageKey.value;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return CupertinoPage<void>(
        key: state.pageKey,
        name: state.name,
        restorationId: restorationId,
        child: child,
      );
    }
    return MaterialPage<void>(
      key: state.pageKey,
      name: state.name,
      restorationId: restorationId,
      child: child,
    );
  }
}

class PawMateBranchReselectController extends ChangeNotifier {
  int? _lastBranchIndex;
  int _serial = 0;

  int? get lastBranchIndex => _lastBranchIndex;
  int get serial => _serial;

  void notifyReselected(int branchIndex) {
    _lastBranchIndex = branchIndex;
    _serial += 1;
    notifyListeners();
  }
}

class PawMateStatefulNavigationHost extends StatefulWidget {
  const PawMateStatefulNavigationHost({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  State<PawMateStatefulNavigationHost> createState() =>
      _PawMateStatefulNavigationHostState();
}

class _PawMateStatefulNavigationHostState
    extends State<PawMateStatefulNavigationHost> {
  final _reselectController = PawMateBranchReselectController();

  @override
  void dispose() {
    _reselectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PawMateNavigationScope(
      navigationShell: widget.navigationShell,
      reselectController: _reselectController,
      child: widget.navigationShell,
    );
  }
}

class PawMateNavigationScope
    extends InheritedNotifier<PawMateBranchReselectController> {
  const PawMateNavigationScope({
    super.key,
    required this.navigationShell,
    required PawMateBranchReselectController reselectController,
    required super.child,
  }) : super(notifier: reselectController);

  final StatefulNavigationShell navigationShell;

  PawMateBranchReselectController get reselectController => notifier!;

  void selectShellLocation(
    String location, {
    BuildContext? scrollContext,
    String? currentLocation,
  }) {
    final targetIndex = AppRouteRegistry.shellBranchIndexForLocation(location);
    if (targetIndex == null) return;
    final isReselect = navigationShell.currentIndex == targetIndex;
    final currentPath = Uri.tryParse(currentLocation ?? '')?.path;
    final rootScrollController =
        isReselect && currentPath == location && scrollContext != null
        ? PrimaryScrollController.maybeOf(scrollContext)
        : null;
    navigationShell.goBranch(targetIndex, initialLocation: isReselect);
    if (isReselect) {
      reselectController.notifyReselected(targetIndex);
    }
    if (rootScrollController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!rootScrollController.hasClients) return;
        rootScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  static PawMateNavigationScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PawMateNavigationScope>();
  }
}
