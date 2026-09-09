import 'package:flutter/material.dart';
import '../core/state.dart';
import 'design.dart';

/// Keep one opaque image in flight, independent of the fading detail sheet.
class ArtworkHero extends StatelessWidget {
  final String tag, image;
  final RyhzeState state;
  final Widget child;
  const ArtworkHero({
    super.key,
    required this.tag,
    required this.image,
    required this.state,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => HeroMode(
    enabled: !state.reduced && !MotionSettings.of(context),
    child: Hero(
      tag: tag,
      createRectTween: (begin, end) => RectTween(begin: begin, end: end),
      flightShuttleBuilder: (_, animation, direction, from, to) =>
          ClipRSuperellipse(
            key: ValueKey('artwork-flight-$tag'),
            borderRadius: BorderRadius.circular(surfaceRadius),
            child: ColoredBox(color: canvas, child: TitleArt(image, state)),
          ),
      child: child,
    ),
  );
}
