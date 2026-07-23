import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

class PawMateSkeleton extends StatefulWidget {
  const PawMateSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppRadius.sm,
    this.circular = false,
    this.animate = true,
  });

  final double width;
  final double height;
  final double borderRadius;
  final bool circular;
  final bool animate;

  @override
  State<PawMateSkeleton> createState() => _PawMateSkeletonState();
}

class _PawMateSkeletonState extends State<PawMateSkeleton>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation(widget.animate && !MediaQuery.disableAnimationsOf(context));
  }

  @override
  void didUpdateWidget(covariant PawMateSkeleton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate == widget.animate) return;
    _syncAnimation(widget.animate && !MediaQuery.disableAnimationsOf(context));
  }

  void _syncAnimation(bool shouldAnimate) {
    if (shouldAnimate == (_controller != null)) return;
    _controller?.dispose();
    _controller = shouldAnimate
        ? (AnimationController(
            vsync: this,
            duration: AppMotion.skeletonPulse,
            lowerBound: 0.55,
            upperBound: 1,
          )..repeat(reverse: true))
        : null;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skeleton = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: PawMateStatusColors.of(context).disabledContainer,
        shape: widget.circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: widget.circular
            ? null
            : BorderRadius.circular(widget.borderRadius),
      ),
    );
    final controller = _controller;
    return ExcludeSemantics(
      child: controller == null
          ? skeleton
          : FadeTransition(opacity: controller, child: skeleton),
    );
  }
}
