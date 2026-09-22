import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Supplies a hover wash for controls without their own focus animation.
class ControllerFocus extends StatefulWidget {
  final Widget child;
  const ControllerFocus({super.key, required this.child});
  static bool activeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ControllerFocusMode>() !=
      null;

  @override
  State<ControllerFocus> createState() => _ControllerFocusState();
}

class _ControllerFocusState extends State<ControllerFocus> {
  OverlayEntry? entry;
  Rect? bounds;
  OutlinedBorder shape = const StadiumBorder();
  bool raise = true;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(focusChanged);
    WidgetsBinding.instance.addPostFrameCallback(track);
  }

  void focusChanged() {
    raise = true;
    // Also refresh when focus changes without an accompanying animation.
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void track(Duration _) {
    if (!mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final focus = FocusManager.instance.primaryFocus;
    final target = focus?.context
        ?.getInheritedWidgetOfExactType<ControllerFocusTarget>();
    final box = focus is FocusScopeNode || target?.outline == false
        ? null
        : focus?.context?.findRenderObject();
    final host = overlay.context.findRenderObject();
    Rect? next;
    OutlinedBorder nextShape = const StadiumBorder();
    if (box is RenderBox && box.attached && box.hasSize && host is RenderBox) {
      final rect = MatrixUtils.transformRect(
        box.getTransformTo(host),
        Offset.zero & box.size,
      );
      final viewport = Offset.zero & host.size;
      if (rect.isFinite &&
          !rect.isEmpty &&
          rect.width * rect.height < viewport.width * viewport.height * .8) {
        if (rect.overlaps(viewport)) {
          next = rect;
          final radius = (target?.radius ?? 32) * (rect.width / box.size.width);
          nextShape = target?.superellipse == true
              ? RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(radius),
                )
              : rect.height <= 64
              ? const StadiumBorder()
              : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius),
                );
        }
      }
    }
    final changed = bounds != next || shape != nextShape;
    bounds = next;
    shape = nextShape;
    if (entry == null || raise) {
      entry?.remove();
      entry?.dispose();
      entry = OverlayEntry(builder: (_) => ring());
      overlay.insert(entry!);
      raise = false;
    } else if (changed) {
      entry!.markNeedsBuild();
    }
    // Observe frames produced by scrolling/animations without starting a loop.
    WidgetsBinding.instance.addPostFrameCallback(track);
  }

  Widget ring() {
    final rect = bounds;
    if (rect == null) return const SizedBox.shrink();
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: CustomPaint(
            key: const ValueKey('controller-selection-hover'),
            painter: _SelectionPainter(shape),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(focusChanged);
    entry?.remove();
    entry?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ControllerFocusMode(child: widget.child);
}

class _ControllerFocusMode extends InheritedTheme {
  const _ControllerFocusMode({required super.child});
  @override
  Widget wrap(BuildContext context, Widget child) =>
      _ControllerFocusMode(child: child);
  @override
  bool updateShouldNotify(_ControllerFocusMode oldWidget) => false;
}

class ControllerFocusTarget extends InheritedWidget {
  final bool outline, superellipse;
  final double radius;
  const ControllerFocusTarget({
    super.key,
    required super.child,
    this.outline = true,
    this.superellipse = false,
    this.radius = 32,
  });
  @override
  bool updateShouldNotify(ControllerFocusTarget oldWidget) =>
      outline != oldWidget.outline ||
      superellipse != oldWidget.superellipse ||
      radius != oldWidget.radius;
}

class _SelectionPainter extends CustomPainter {
  final OutlinedBorder shape;
  const _SelectionPainter(this.shape);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawPath(
      shape.getOuterPath(rect),
      Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0x20d6c3ff),
    );
  }

  @override
  bool shouldRepaint(_SelectionPainter oldDelegate) =>
      shape != oldDelegate.shape;
}
