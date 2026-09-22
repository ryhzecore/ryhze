import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../core/state.dart';
import 'design.dart';

const artworkTransitionMilliseconds = surfaceTransitionMilliseconds;

/// One continuous, reversible path from the card to its detail artwork.
class DirectArtworkRectTween extends RectTween {
  DirectArtworkRectTween({required super.begin, required super.end});

  @override
  Rect? lerp(double t) {
    double ease(double value) => value * value * (3 - 2 * value);
    if (begin == null || end == null) return super.lerp(t);
    if (t <= 0) return begin;
    if (t >= 1) return end;
    return Rect.lerp(begin, end, ease(t));
  }
}

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
  final double progress;
  const GameFrameMotion({
    super.key,
    required this.moving,
    this.reduced = false,
    this.progress = 1,
    required super.child,
  });
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameFrameMotion>()?.moving ??
      false;
  static bool ownsFrame(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameFrameMotion>() != null;
  @override
  bool updateShouldNotify(GameFrameMotion old) =>
      moving != old.moving ||
      reduced != old.reduced ||
      progress != old.progress;
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
          final t = reduced || source == null ? 1.0 : animation.value;
          // Keep the frame and artwork on the same uninterrupted timeline.
          final rect = Rect.lerp(
            source ?? target,
            target,
            t * t * (3 - 2 * t),
          )!;
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
                  progress: t,
                  reduced: reduced,
                  child: child!,
                ),
              ),
              Positioned.fromRect(
                rect: rect,
                child: IgnorePointer(
                  child: DecoratedBox(
                    key: const ValueKey('game-frame-stroke'),
                    decoration: ShapeDecoration(
                      shape: RoundedSuperellipseBorder(
                        borderRadius: radius,
                        side: const BorderSide(color: Color(0x35ffffff)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Controls share the frame timeline in both directions; no delayed second animation.
class DetailControlsReveal extends StatelessWidget {
  final Widget child;
  const DetailControlsReveal({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final frame = context.dependOnInheritedWidgetOfExactType<GameFrameMotion>();
    final immediate =
        frame == null || frame.reduced || MotionSettings.of(context);
    final progress = immediate ? 1.0 : frame.progress;
    final value = Curves.easeOutCubic.transform(
      ((progress - .72) / .28).clamp(0.0, 1.0),
    );
    final interactive = immediate || !frame.moving;
    return IgnorePointer(
      ignoring: !interactive,
      child: ExcludeSemantics(
        excluding: !interactive,
        child: Opacity(
          opacity: value,
          child: ImageFiltered(
            enabled: value > 0 && value < 1,
            imageFilter: ImageFilter.blur(
              sigmaX: 4 * (1 - value),
              sigmaY: 4 * (1 - value),
            ),
            child: RepaintBoundary(child: child),
          ),
        ),
      ),
    );
  }
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
      curve: Curves.linear,
      reverseCurve: Curves.linear,
      createRectTween: (begin, end) =>
          DirectArtworkRectTween(begin: begin, end: end),
      flightShuttleBuilder: (_, animation, direction, from, to) {
        final cardContext = direction == HeroFlightDirection.push ? from : to;
        final detailContext = direction == HeroFlightDirection.push ? to : from;
        Rect bounds(BuildContext context) {
          final box = context.findRenderObject()! as RenderBox;
          return MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
        }
        final card = bounds(cardContext), detail = bounds(detailContext);
        final media = MediaQuery.of(detailContext);
        final mobile = media.size.width <= 700;
        final margin = mobile ? 12.0 : 24.0;
        final width = (media.size.width - media.padding.horizontal - margin * 2).clamp(0.0, 1080.0);
        final panel = Rect.fromLTRB(
          media.padding.left + (media.size.width - media.padding.horizontal - width) / 2,
          media.padding.top + margin,
          media.padding.left + (media.size.width - media.padding.horizontal + width) / 2,
          media.size.height - media.padding.bottom - margin,
        );
        return AnimatedBuilder(
          animation: animation,
          child: ClipRSuperellipse(
            key: ValueKey('artwork-flight-$tag'),
            borderRadius: BorderRadius.circular(surfaceRadius),
            child: ColoredBox(
              color: canvas,
              child: artwork ?? TitleArt(image, state),
            ),
          ),
          builder: (context, child) {
            final t = animation.value;
            final eased = t * t * (3 - 2 * t);
            final flight = Rect.lerp(card, detail, eased)!;
            final frame = Rect.lerp(card, panel, eased)!;
            final radius = BorderRadius.circular(surfaceRadius + (panelRadius(mobile) - surfaceRadius) * t);
            return ClipRSuperellipse(
              clipper: _FrameClip(frame.shift(-flight.topLeft), radius),
              child: child,
            );
          },
        );
      },
      child: child,
    ),
  );
}
