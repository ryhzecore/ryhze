import 'dart:ui';
import 'package:flutter/material.dart';
import 'design.dart';

/// One route owns both directions, including dismissal during expansion.
Future<T?> expandingSurface<T>({
  required BuildContext context,
  required GlobalKey source,
  required IconData icon,
  required WidgetBuilder builder,
  required double width,
  required double height,
  bool rightAligned = false,
  bool reduced = false,
}) async {
  final box = source.currentContext?.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  reduced =
      reduced ||
      MotionSettings.of(context) ||
      MediaQuery.disableAnimationsOf(context);
  final route = RawDialogRoute<T>(
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x88000000),
    transitionDuration: Duration(milliseconds: reduced ? 0 : 280),
    pageBuilder: (context, animation, secondary) => LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final available = constraints.biggest;
        final gutter = available.width <= 700
            ? 20.0
            : (available.width * .045).clamp(20.0, 88.0);
        final w = width.clamp(
          0.0,
          (available.width - gutter * 2).clamp(0.0, double.infinity),
        );
        final top = media.padding.top + 18;
        final h = height.clamp(
          0.0,
          (available.height - top - media.viewInsets.bottom - 20).clamp(
            0.0,
            double.infinity,
          ),
        );
        final target = Rect.fromLTWH(
          rightAligned
              ? available.width - gutter - w
              : (available.width - w) / 2,
          top,
          w,
          h,
        );
        final start =
            origin ??
            Rect.fromCenter(center: target.topCenter, width: 48, height: 48);
        return AnimatedBuilder(
          animation: animation,
          child: Material(
            type: MaterialType.transparency,
            child: builder(context),
          ),
          builder: (context, child) {
            final t = reduced ? 1.0 : ryhzeEase.transform(animation.value);
            final rect = Rect.lerp(start, target, t)!;
            return Stack(
              children: [
                Positioned.fromRect(
                  rect: rect,
                  child: ClipRSuperellipse(
                    key: const ValueKey('expanding-surface'),
                    borderRadius: BorderRadius.circular(
                      lerpDouble(24, popoverRadius, t)!,
                    ),
                    child: Glass(
                      radius: popoverRadius,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Opacity(
                              opacity: 1 - t,
                              child: Icon(icon, color: Colors.white),
                            ),
                          ),
                          OverflowBox(
                            alignment: Alignment.topLeft,
                            minWidth: w,
                            maxWidth: w,
                            minHeight: h,
                            maxHeight: h,
                            child: IgnorePointer(
                              ignoring:
                                  animation.status == AnimationStatus.reverse,
                              child: Opacity(
                                opacity: ((t - .15) / .85).clamp(0.0, 1.0),
                                child: child,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ),
    transitionBuilder: (_, _, _, child) => child,
  );
  final result = await Navigator.of(context, rootNavigator: true).push(route);
  await route.completed;
  return result;
}
