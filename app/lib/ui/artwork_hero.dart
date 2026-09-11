import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../core/state.dart';
import 'design.dart';

Rect? artworkBounds(BuildContext context, String tag) {
  Rect? result;
  void visit(Element element) {
    if (element.widget case ArtworkHero(tag: final value) when value == tag) {
      final box = element.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        result = MatrixUtils.transformRect(
          box.getTransformTo(null),
          Offset.zero & box.size,
        );
      }
    }
    if (result == null) element.visitChildElements(visit);
  }

  context.visitChildElements(visit);
  return result;
}

/// Reveal the whole game frame from the same bounds as its artwork flight.
class GameFrameMotion extends InheritedWidget {
  final bool moving;
  final bool reduced;
  const GameFrameMotion({
    super.key,
    required this.moving,
    this.reduced = false,
    required super.child,
  });
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameFrameMotion>()?.moving ??
      false;
  static bool ownsFrame(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameFrameMotion>() != null;
  @override
  bool updateShouldNotify(GameFrameMotion old) =>
      moving != old.moving || reduced != old.reduced;
}

class GameFrameTransition extends StatelessWidget {
  final Animation<double> animation;
  final Rect? source;
  final Widget child;
  final bool reduced;

  const GameFrameTransition({
    super.key,
    required this.animation,
    required this.source,
    required this.child,
    this.reduced = false,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final padding = MediaQuery.paddingOf(context);
      final mobile = bounds.maxWidth <= 700;
      final margin = mobile ? 12.0 : 24.0;
      final width = (bounds.maxWidth - padding.horizontal - margin * 2).clamp(
        0.0,
        1080.0,
      );

      final target = Rect.fromLTRB(
        padding.left + (bounds.maxWidth - padding.horizontal - width) / 2,
        padding.top + margin,
        padding.left + (bounds.maxWidth - padding.horizontal + width) / 2,
        bounds.maxHeight - padding.bottom - margin,
      );
      return AnimatedBuilder(
        animation: animation,
        child: RepaintBoundary(child: child),
        builder: (context, child) {
          final t = reduced || source == null
              ? 1.0
              : ryhzeEase.transform(animation.value);
          final rect = Rect.lerp(source ?? target, target, t)!;
          final radius = BorderRadius.circular(
            surfaceRadius + (panelRadius(mobile) - surfaceRadius) * t,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: rect,
                child: DecoratedBox(
                  key: const ValueKey('expanding-game-frame'),
                  decoration: ShapeDecoration(
                    color: const Color(0xff111014),
                    shape: RoundedSuperellipseBorder(
                      borderRadius: radius,
                      side: const BorderSide(color: Color(0x25ffffff)),
                    ),
                  ),
                ),
              ),
              ClipRSuperellipse(
                clipper: _FrameClip(rect, radius),
                clipBehavior: Clip.antiAlias,
                child: GameFrameMotion(
                  moving: t != 1,
                  reduced: reduced,
                  child: child!,
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Keep controls still and hidden during the artwork flight, then reveal them.
class DetailControlsReveal extends StatefulWidget {
  final Widget child;
  const DetailControlsReveal({super.key, required this.child});
  @override
  State<DetailControlsReveal> createState() => _DetailControlsRevealState();
}

class _DetailControlsRevealState extends State<DetailControlsReveal>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final frame = context.dependOnInheritedWidgetOfExactType<GameFrameMotion>();
    if (frame == null || frame.reduced || MotionSettings.of(context)) {
      controller.value = 1;
    } else if (frame.moving) {
      controller.value = 0;
    } else {
      controller.forward();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: RepaintBoundary(child: widget.child),
    builder: (context, child) {
      final value = Curves.easeOutCubic.transform(controller.value);
      return IgnorePointer(
        ignoring: value < 1,
        child: ExcludeSemantics(
          excluding: value < 1,
          child: Opacity(
            opacity: value,
            child: ImageFiltered(
              enabled: value > 0 && value < 1,
              imageFilter: ImageFilter.blur(
                sigmaX: 4 * (1 - value),
                sigmaY: 4 * (1 - value),
              ),
              child: child!,
            ),
          ),
        ),
      );
    },
  );
}

class _FrameClip extends CustomClipper<RSuperellipse> {
  final Rect rect;
  final BorderRadius radius;
  const _FrameClip(this.rect, this.radius);
  @override
  RSuperellipse getClip(Size size) => radius.toRSuperellipse(rect);
  @override
  bool shouldReclip(_FrameClip old) => rect != old.rect || radius != old.radius;
}

/// Keep one opaque image in flight above the connected frame.
class ArtworkHero extends StatelessWidget {
  final String tag, image;
  final RyhzeState state;
  final Widget child;
  final Widget? artwork;
  const ArtworkHero({
    super.key,
    required this.tag,
    required this.image,
    required this.state,
    required this.child,
    this.artwork,
  });
  @override
  Widget build(BuildContext context) => HeroMode(
    enabled: !state.reduced && !MotionSettings.of(context),
    child: Hero(
      tag: tag,
      curve: ryhzeEase,
      reverseCurve: ryhzeEase,
      createRectTween: (begin, end) => RectTween(begin: begin, end: end),
      flightShuttleBuilder: (_, animation, direction, from, to) =>
          ClipRSuperellipse(
            key: ValueKey('artwork-flight-$tag'),
            borderRadius: BorderRadius.circular(surfaceRadius),
            child: ColoredBox(
              color: canvas,
              child: artwork ?? TitleArt(image, state),
            ),
          ),
      child: child,
    ),
  );
}
