import 'package:flutter/material.dart';

/// Slow camera drift for featured artwork; text and library cards stay still.
class FeaturedArtworkMotion extends StatefulWidget {
  final Widget child;
  final bool active, reduced;
  const FeaturedArtworkMotion({
    super.key,
    required this.child,
    this.active = true,
    this.reduced = false,
  });
  @override
  State<FeaturedArtworkMotion> createState() => _FeaturedArtworkMotionState();
}

class _FeaturedArtworkMotionState extends State<FeaturedArtworkMotion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );
  bool foreground = true;
  bool get reduced => widget.reduced || MediaQuery.disableAnimationsOf(context);
  void sync() {
    if (widget.active && !reduced && foreground && TickerMode.valuesOf(context).enabled) {
      if (!controller.isAnimating) controller.repeat(reverse: true);
    } else {
      controller.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sync();
  }

  @override
  void didUpdateWidget(FeaturedArtworkMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: LayoutBuilder(
      builder: (context, bounds) => AnimatedBuilder(
        animation: controller,
        child: RepaintBoundary(child: widget.child),
        builder: (context, child) {
          final t = Curves.easeInOutSine.transform(controller.value);
          final matrix = Matrix4.identity();
          if (!reduced) {
            matrix
              ..translateByDouble(
                bounds.maxWidth * (-.012 + .024 * t),
                bounds.maxHeight * (.004 - .008 * t),
                0,
                1,
              )
              ..scaleByDouble(1.04 + .045 * t, 1.04 + .045 * t, 1, 1);
          }
          return Transform(
            key: const ValueKey('featured-artwork-drift'),
            alignment: Alignment.center,
            transform: matrix,
            child: child,
          );
        },
      ),
    ),
  );
}
