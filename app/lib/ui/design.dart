import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/state.dart';

const canvas = Color(0xff09090c);
const muted = Color(0xffa9a8b3);
const violet = Color(0xff5500ff);
const ryhzeEase = Cubic(.22, .68, .18, 1);
const surfaceRadius = 32.0;
const popoverRadius = 28.0;
double panelRadius(bool mobile) => mobile ? 36 : 44;
TextStyle heading(double size) => TextStyle(
  fontFamily: 'Space Grotesk',
  fontSize: size,
  fontWeight: FontWeight.w500,
  letterSpacing: -size * .045,
  height: 1.04,
  color: const Color(0xfff8f7fa),
);
ThemeData ryhzeTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: canvas,
  fontFamily: 'Inter',
  visualDensity: VisualDensity.standard,
  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xfff9f8fb),
    onPrimary: Color(0xff19131f),
    secondary: Color(0xffbf70ff),
    surface: Color(0xff17171d),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 14, height: 1.75, color: Color(0xffbdbbc8)),
  ),
  tooltipTheme: const TooltipThemeData(
    waitDuration: Duration(milliseconds: 600),
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled)
            ? const Color(0xff77737e)
            : s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)
            ? Colors.white
            : const Color(0xffdad8e2),
      ),
      overlayColor: const WidgetStatePropertyAll(Color(0x0cffffff)),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0x07ffffff),
    contentPadding: const EdgeInsets.all(16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0x28ffffff)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0x28ffffff)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xffd3c6ec)),
    ),
  ),
  dividerColor: const Color(0x20ffffff),
  splashFactory: NoSplash.splashFactory,
);

class MotionSettings extends InheritedWidget {
  final bool reduced;
  const MotionSettings({
    super.key,
    required this.reduced,
    required super.child,
  });
  static bool of(BuildContext context) =>
      (context.dependOnInheritedWidgetOfExactType<MotionSettings>()?.reduced ??
          false) ||
      MediaQuery.disableAnimationsOf(context);
  @override
  bool updateShouldNotify(MotionSettings oldWidget) =>
      reduced != oldWidget.reduced;
}

class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 10,
      letterSpacing: 1.9,
      fontWeight: FontWeight.w500,
      color: Color(0xffc8c2d4),
      height: 1.6,
    ),
  );
}

class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  const Glass({
    super.key,
    required this.child,
    this.radius = surfaceRadius,
    this.padding = EdgeInsets.zero,
  });
  @override
  Widget build(BuildContext context) => ClipRSuperellipse(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(
        padding: padding,
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(radius),
            side: const BorderSide(color: Color(0x22ffffff)),
          ),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xe027272e), Color(0xe01a1a20)],
          ),
        ),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    ),
  );
}

class Pill extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary, iconOnly, reduced, iconFirst, quiet, backStyle;
  final double height;
  const Pill(
    this.label, {
    super.key,
    this.icon,
    this.onPressed,
    this.primary = false,
    this.iconOnly = false,
    this.reduced = false,
    this.iconFirst = false,
    this.quiet = false,
    this.backStyle = false,
    this.height = 48,
  });
  @override
  State<Pill> createState() => _PillState();
}

class _PillState extends State<Pill> {
  final states = WidgetStatesController();
  bool repaintQueued = false;
  @override
  void initState() {
    super.initState();
    states.addListener(statesChanged);
  }

  void statesChanged() {
    if (repaintQueued || !mounted) return;
    repaintQueued = true;
    // Buttons may update their states while building. Paint hover/focus changes
    // after that frame rather than invalidating an ancestor during its build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      repaintQueued = false;
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    states.removeListener(statesChanged);
    states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Builder(
    builder: (context) {
      final reduced = widget.reduced || MotionSettings.of(context);
      final enabled = widget.onPressed != null;
      final hover = enabled && states.value.contains(WidgetState.hovered);
      final focus = enabled && states.value.contains(WidgetState.focused);
      final pressed = enabled && states.value.contains(WidgetState.pressed);
      final duration = Duration(milliseconds: reduced ? 0 : 550);
      return AnimatedScale(
        scale: reduced
            ? 1
            : pressed
            ? .975
            : hover
            ? 1.055
            : 1,
        duration: duration,
        curve: ryhzeEase,
        child: AnimatedContainer(
          duration: duration,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: hover && !widget.backStyle
                ? const [
                    BoxShadow(
                      color: Color(0x22000000),
                      offset: Offset(0, 8),
                      blurRadius: 28,
                    ),
                  ]
                : const [],
          ),
          child: Tooltip(
            message: widget.iconOnly ? widget.label : '',
            child: Semantics(
              button: true,
              label: widget.iconOnly ? widget.label : null,
              child: TextButton(
                statesController: states,
                onPressed: widget.onPressed,
                style: ButtonStyle(
                  visualDensity: VisualDensity.standard,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.center,
                  animationDuration: duration,
                  overlayColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  fixedSize: widget.iconOnly
                      ? WidgetStatePropertyAll(Size.square(widget.height))
                      : null,
                  minimumSize: WidgetStatePropertyAll(
                    Size(widget.iconOnly ? widget.height : 0, widget.height),
                  ),
                  padding: WidgetStatePropertyAll(
                    widget.iconOnly
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(
                            horizontal: 21,
                            vertical: 13,
                          ),
                  ),
                  foregroundColor: WidgetStatePropertyAll(
                    !enabled
                        ? const Color(0xff77737e)
                        : widget.primary
                        ? const Color(0xff19131f)
                        : const Color(0xfff8f7fa),
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => widget.primary
                        ? (states.contains(WidgetState.hovered)
                              ? const Color(0xffe9e1f8)
                              : const Color(0xfff9f8fb))
                        : hover
                        ? const Color(0x16ffffff)
                        : widget.quiet
                        ? Colors.transparent
                        : const Color(0x08ffffff),
                  ),
                  side: WidgetStateProperty.resolveWith(
                    (states) => BorderSide(
                      width: focus && widget.backStyle ? 2 : 1,
                      color: focus
                          ? Colors.white
                          : hover
                          ? const Color(0x60ffffff)
                          : widget.primary
                          ? const Color(0xfff9f8fb)
                          : widget.quiet
                          ? Colors.transparent
                          : const Color(0x26ffffff),
                    ),
                  ),
                  shape: const WidgetStatePropertyAll(StadiumBorder()),
                ),
                child: widget.iconOnly
                    ? Icon(widget.icon, size: 20)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null && widget.iconFirst) ...[
                            Icon(widget.icon, size: 19),
                            const SizedBox(width: 10),
                          ],
                          Flexible(
                            child: Text(
                              widget.label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                                leadingDistribution:
                                    TextLeadingDistribution.even,
                              ),
                            ),
                          ),
                          if (widget.icon != null && !widget.iconFirst) ...[
                            const SizedBox(width: 10),
                            Icon(widget.icon, size: 19),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Both the painted pill and the hit targets use the same cell geometry.
class BrowseTabs extends StatefulWidget {
  final String page;
  final ValueChanged<String> onChanged;
  final bool engineAvailable;
  const BrowseTabs({
    super.key,
    required this.page,
    required this.onChanged,
    this.engineAvailable = false,
  });
  @override
  State<BrowseTabs> createState() => _BrowseTabsState();
}

class _BrowseTabsState extends State<BrowseTabs> {
  int? pointer;
  double? dragX;
  bool dragging = false;
  bool suppressTap = false;
  Offset? down;
  final trackKey = GlobalKey();
  String get page => widget.page;
  List<String> get modes => [
    'games',
    'films',
    if (widget.engineAvailable) 'engine',
  ];
  void onChanged(String page) => widget.onChanged(page);

  Offset local(Offset global) =>
      (trackKey.currentContext!.findRenderObject() as RenderBox).globalToLocal(
        global,
      );

  void finish(
    PointerEvent event,
    double cell,
    double gap, {
    bool cancel = false,
  }) {
    if (pointer != event.pointer) return;
    final point = local(event.position);
    final commit = dragging && !cancel && point.dy >= -24 && point.dy <= 68;
    suppressTap = dragging || cancel;
    Future.microtask(() => suppressTap = false);
    final target =
        modes[((dragX ?? 0) / (cell + gap)).round().clamp(0, modes.length - 1)];
    setState(() {
      pointer = null;
      dragX = null;
      dragging = false;
      down = null;
    });
    if (commit) onChanged(target);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width <= 480;
    final cell = width <= 350
        ? 57.0
        : compact
        ? 61.0
        : width <= 700
        ? 66.0
        : 80.0;
    final gap = compact ? 2.0 : 4.0;
    final selected = dragX == null
        ? page
        : modes[(dragX! / (cell + gap)).round().clamp(0, modes.length - 1)];
    final stretch = dragging && !MotionSettings.of(context)
        ? .16 * (1 - (2 * ((dragX! / (cell + gap)) % 1) - 1).abs())
        : 0.0;
    return Glass(
      radius: 999,
      padding: EdgeInsets.all(compact ? 4 : 5),
      child: SizedBox(
        key: trackKey,
        width: cell * modes.length + gap * (modes.length - 1),
        height: 44,
        child: Listener(
          onPointerDown: (event) {
            if (pointer != null || event.buttons != 1) return;
            setState(() {
              suppressTap = false;
              pointer = event.pointer;
              down = local(event.position);
            });
          },
          onPointerMove: (event) {
            if (pointer != event.pointer) return;
            final position = local(event.position);
            if (!dragging && (position.dx - down!.dx).abs() < 4) return;
            setState(() {
              dragging = true;
              dragX = (position.dx - cell / 2).clamp(
                0.0,
                (cell + gap) * (modes.length - 1),
              );
            });
          },
          onPointerUp: (event) => finish(event, cell, gap),
          onPointerCancel: (event) => finish(event, cell, gap, cancel: true),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: Duration(
                  milliseconds: MotionSettings.of(context) || dragging
                      ? 0
                      : 300,
                ),
                curve: ryhzeEase,
                left:
                    dragX ??
                    modes.indexOf(page).clamp(0, modes.length - 1) *
                        (cell + gap),
                top: 0,
                width: cell,
                height: 44,
                child: IgnorePointer(
                  child: AnimatedScale(
                    scale: pointer != null && !MotionSettings.of(context)
                        ? 1.08
                        : 1,
                    duration: Duration(
                      milliseconds: MotionSettings.of(context) ? 0 : 180,
                    ),
                    curve: ryhzeEase,
                    child: AnimatedContainer(
                      duration: Duration(
                        milliseconds: dragging || MotionSettings.of(context)
                            ? 0
                            : 180,
                      ),
                      curve: ryhzeEase,
                      transformAlignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(1 + stretch, 1, 1),
                      child: DecoratedBox(
                        key: const ValueKey('browse-selection'),
                        decoration: BoxDecoration(
                          color: pointer != null || modes.contains(page)
                              ? const Color(0xfffaf9fc)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final mode in modes) ...[
                    if (mode != modes.first) SizedBox(width: gap),
                    SizedBox(
                      width: cell,
                      height: 44,
                      child: Semantics(
                        selected: page == mode,
                        child: TextButton(
                          key: ValueKey('browse-$mode'),
                          onPressed: () {
                            if (pointer == null && !suppressTap) {
                              onChanged(mode);
                            }
                          },
                          style: ButtonStyle(
                            animationDuration: Duration.zero,
                            padding: const WidgetStatePropertyAll(
                              EdgeInsets.zero,
                            ),
                            minimumSize: const WidgetStatePropertyAll(
                              Size.zero,
                            ),
                            shape: const WidgetStatePropertyAll(
                              StadiumBorder(),
                            ),
                            overlayColor: const WidgetStatePropertyAll(
                              Colors.transparent,
                            ),
                            backgroundColor: WidgetStateProperty.resolveWith(
                              (s) =>
                                  selected != mode &&
                                      s.contains(WidgetState.hovered)
                                  ? const Color(0x16ffffff)
                                  : Colors.transparent,
                            ),
                            side: WidgetStateProperty.resolveWith(
                              (s) => BorderSide(
                                color: s.contains(WidgetState.focused)
                                    ? Colors.white
                                    : Colors.transparent,
                              ),
                            ),
                            foregroundColor: WidgetStateProperty.resolveWith(
                              (s) => selected == mode
                                  ? const Color(0xff1a1420)
                                  : s.contains(WidgetState.hovered)
                                  ? Colors.white
                                  : const Color(0xffb8b4c3),
                            ),
                            textStyle: WidgetStatePropertyAll(
                              TextStyle(
                                fontFamily: 'Inter',
                                fontSize: width <= 700 ? 12 : 13,
                                fontWeight: FontWeight.w400,
                                height: 1.3,
                                leadingDistribution:
                                    TextLeadingDistribution.even,
                              ),
                            ),
                          ),
                          child: Text(
                            mode == 'games'
                                ? 'Games'
                                : mode == 'films'
                                ? 'Films'
                                : 'Engine',
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TitleArt extends StatelessWidget {
  final String path;
  final RyhzeState state;
  final BoxFit fit;
  final Alignment alignment;
  const TitleArt(
    this.path,
    this.state, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });
  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext _, Object error, StackTrace? stack) =>
        Container(
          color: const Color(0xff17171d),
          child: const Center(
            child: Icon(Icons.landscape_outlined, color: muted, size: 36),
          ),
        );
    if (path.isEmpty) return fallback(context, '', null);
    if ([
      '/art/san-coronado.png',
      '/art/gta-vi.png',
      '/art/valorant.png',
    ].contains(path)) {
      return Image.asset(
        'assets$path',
        fit: fit,
        alignment: alignment,
        errorBuilder: fallback,
      );
    }
    try {
      return Image.network(
        state.api.resource(path).toString(),
        headers: state.api.authHeaders,
        fit: fit,
        alignment: alignment,
        errorBuilder: fallback,
      );
    } catch (_) {
      return fallback(context, '', null);
    }
  }
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xff28242f),
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
}

Future<void> attempt(BuildContext context, Future<void> Function() work) async {
  try {
    await work();
  } catch (e) {
    if (context.mounted) toast(context, e.toString());
  }
}
