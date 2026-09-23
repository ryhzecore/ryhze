import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:real_liquid_glass/real_liquid_glass.dart';
import '../core/state.dart';
import 'controller_focus.dart';

const canvas = Color(0xff09090c);
const muted = Color(0xffa9a8b3);
const violet = Color(0xff5500ff);
const ryhzeEase = Cubic(.22, .68, .18, 1);
const surfaceTransitionMilliseconds = 280;
const surfaceRadius = 32.0;
const popoverRadius = surfaceRadius;

/// The native effect is intentionally limited to iOS. The package also
/// supports macOS, but Ryhze's existing macOS and other platform visuals must
/// stay unchanged.
bool get usesIOSLiquidGlass =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

Widget _iosGlassButtonLayer(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) => LiquidGlassContainer(
  shape: const LiquidGlassShape.capsule(),
  style: LiquidGlassStyle.regular,
  interactive: false,
  child: child,
);

Widget _iosPrimaryGlassButtonLayer(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) => LiquidGlassContainer(
  shape: const LiquidGlassShape.capsule(),
  style: LiquidGlassStyle.regular,
  tint: const Color(0x405500ff),
  interactive: false,
  child: child,
);

Widget _buttonLayerPassthrough(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) => child ?? const SizedBox.shrink();

/// A status surface, never an action: real progress or a slow unknown-duration fill.
class StatusProgress extends StatefulWidget {
  final String label;
  final double? value;
  const StatusProgress({super.key, this.label = 'Loading', this.value});
  factory StatusProgress.fromMessage(String message) {
    final match = RegExp(r'(\d{1,3})%').firstMatch(message);
    return StatusProgress(
      label: match == null
          ? message
          : message.replaceFirst(match.group(0)!, '').trim(),
      value: match == null
          ? null
          : int.parse(match.group(1)!).clamp(0, 100) / 100,
    );
  }
  @override
  State<StatusProgress> createState() => _StatusProgressState();
}

class _StatusProgressState extends State<StatusProgress>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  bool reduced = false, visible = true;
  void sync() {
    if (!reduced &&
        visible &&
        widget.value == null &&
        TickerMode.valuesOf(context).enabled) {
      if (!controller.isAnimating) controller.repeat();
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
    reduced =
        MotionSettings.of(context) || MediaQuery.disableAnimationsOf(context);
    sync();
  }

  @override
  void didUpdateWidget(StatusProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    visible = state == AppLifecycleState.resumed;
    sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    value: widget.value == null
        ? 'In progress'
        : '${(widget.value!.clamp(0, 1) * 100).floor()}%',
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, bounds) => SizedBox(
          width: bounds.hasBoundedWidth
              ? bounds.maxWidth.clamp(0.0, 560.0)
              : 360,
          height: 48,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xff19171e),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x30ffffff)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.value != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        key: const ValueKey('actual-progress-fill'),
                        widthFactor: widget.value!.clamp(0.0, 1.0),
                        heightFactor: 1,
                        child: const ColoredBox(color: Color(0x705500ff)),
                      ),
                    ),
                  if (widget.value == null)
                    AnimatedBuilder(
                      animation: controller,
                      builder: (_, _) {
                        final t = reduced ? .38 : controller.value;
                        return Opacity(
                          opacity: reduced || t < .82
                              ? 1
                              : ((1 - t) / .18).clamp(0.0, 1.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor:
                                  .08 + .84 * Curves.easeInOut.transform(t),
                              heightFactor: 1,
                              child: const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0x305500ff),
                                      Color(0x805500ff),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        widget.value == null
                            ? widget.label
                            : '${widget.label} ${(widget.value!.clamp(0, 1) * 100).floor()}%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

double artworkAspectRatio(double viewportWidth) =>
    viewportWidth <= 480 ? 1.6 : 1.5;
double detailGutter(bool mobile) => mobile ? 20 : 24;
double detailSectionGap(bool mobile) => mobile ? 20 : 24;
double detailTitleSize(double width) => width <= 350
    ? 32
    : width <= 700
    ? 38
    : (width * .045).clamp(32, 62);

double panelRadius(bool mobile) => surfaceRadius;
TextStyle heading(double size) => TextStyle(
  fontFamily: 'Space Grotesk',
  fontSize: size,
  fontWeight: FontWeight.w500,
  letterSpacing: -size * .045,
  height: 1.04,
  color: const Color(0xfff8f7fa),
);
ThemeData ryhzeTheme() {
  final iosGlass = usesIOSLiquidGlass;
  final glassButtonStyle = ButtonStyle(
    shape: const WidgetStatePropertyAll(StadiumBorder()),
    backgroundColor: iosGlass
        ? const WidgetStatePropertyAll(Colors.transparent)
        : null,
    side: iosGlass
        ? const WidgetStatePropertyAll(BorderSide(color: Color(0x38ffffff)))
        : null,
    surfaceTintColor: iosGlass
        ? const WidgetStatePropertyAll(Colors.transparent)
        : null,
    backgroundBuilder: iosGlass ? _iosGlassButtonLayer : null,
  );
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: canvas,
    hoverColor: Colors.transparent,
    highlightColor: Colors.transparent,
    focusColor: Colors.transparent,
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
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.75,
        color: Color(0xffbdbbc8),
      ),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: Color(0xfff8f7fa),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: glassButtonStyle.copyWith(
        foregroundColor: iosGlass
            ? const WidgetStatePropertyAll(Colors.white)
            : null,
        backgroundBuilder: iosGlass ? _iosPrimaryGlassButtonLayer : null,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(style: glassButtonStyle),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: glassButtonStyle.copyWith(
        elevation: iosGlass ? const WidgetStatePropertyAll(0) : null,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(style: glassButtonStyle),
    popupMenuTheme: PopupMenuThemeData(
      position: PopupMenuPosition.over,
      color: iosGlass ? const Color(0xd9202026) : const Color(0xff202026),
      surfaceTintColor: Colors.transparent,
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(popoverRadius),
        side: const BorderSide(color: Color(0x22ffffff)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: iosGlass ? const Color(0xd91b1b21) : null,
      surfaceTintColor: iosGlass ? Colors.transparent : null,
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(surfaceRadius),
        side: const BorderSide(color: Color(0x22ffffff)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? const Color(0xff77737e)
              : s.contains(WidgetState.hovered) ||
                    s.contains(WidgetState.focused)
              ? Colors.white
              : const Color(0xffdad8e2),
        ),
        backgroundColor: iosGlass
            ? const WidgetStatePropertyAll(Colors.transparent)
            : null,
        overlayColor: const WidgetStatePropertyAll(Color(0x0cffffff)),
        side: iosGlass
            ? const WidgetStatePropertyAll(BorderSide(color: Color(0x32ffffff)))
            : null,
        backgroundBuilder: iosGlass ? _iosGlassButtonLayer : null,
        shape: const WidgetStatePropertyAll(StadiumBorder()),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: iosGlass
          ? const ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Colors.transparent),
              side: WidgetStatePropertyAll(
                BorderSide(color: Color(0x32ffffff)),
              ),
              shape: WidgetStatePropertyAll(CircleBorder()),
              backgroundBuilder: _iosGlassButtonLayer,
            )
          : null,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: iosGlass ? const Color(0x14ffffff) : const Color(0x07ffffff),
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(popoverRadius),
        borderSide: const BorderSide(color: Color(0x28ffffff)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(popoverRadius),
        borderSide: const BorderSide(color: Color(0x28ffffff)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(popoverRadius),
        borderSide: const BorderSide(color: Color(0xffd3c6ec)),
      ),
    ),
    dividerColor: const Color(0x20ffffff),
    splashFactory: NoSplash.splashFactory,
  );
}

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
  final bool frameVisible;
  const Glass({
    super.key,
    required this.child,
    this.radius = surfaceRadius,
    this.padding = EdgeInsets.zero,
    this.frameVisible = true,
  });
  @override
  Widget build(BuildContext context) {
    final content = Material(type: MaterialType.transparency, child: child);
    if (usesIOSLiquidGlass && frameVisible) {
      return LiquidGlassContainer(
        shape: LiquidGlassShape.roundedRectangle(radius),
        style: LiquidGlassStyle.regular,
        padding: padding,
        // Flutter keeps ownership of hit testing and semantics. The native
        // view remains a bounded, non-intercepting material behind the child.
        interactive: false,
        child: content,
      );
    }
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        enabled: frameVisible,
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: ShapeDecoration(
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(
                color: frameVisible
                    ? const Color(0x22ffffff)
                    : Colors.transparent,
              ),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: frameVisible
                  ? const [Color(0xe027272e), Color(0xe01a1a20)]
                  : const [Colors.transparent, Colors.transparent],
            ),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Adds native glass to shared chrome on iOS while returning the original
/// widget unchanged everywhere else.
class IOSGlassChrome extends StatelessWidget {
  final Widget child;
  final double radius;
  const IOSGlassChrome({
    super.key,
    required this.child,
    this.radius = surfaceRadius,
  });

  @override
  Widget build(BuildContext context) =>
      usesIOSLiquidGlass ? Glass(radius: radius, child: child) : child;
}

/// Alert dialogs keep the exact Material implementation off iOS and use one
/// bounded native glass surface for their frame on iOS.
class RyhzeAlertDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  const RyhzeAlertDialog({super.key, this.title, this.content, this.actions});

  @override
  Widget build(BuildContext context) {
    if (!usesIOSLiquidGlass) {
      return AlertDialog(title: title, content: content, actions: actions);
    }
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      child: Glass(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                DefaultTextStyle(
                  style: theme.textTheme.headlineSmall!,
                  child: title!,
                ),
              if (title != null && content != null) const SizedBox(height: 16),
              if (content != null)
                Flexible(
                  fit: FlexFit.loose,
                  child: DefaultTextStyle(
                    style: theme.textTheme.bodyMedium!,
                    child: content!,
                  ),
                ),
              if (actions case final actions? when actions.isNotEmpty) ...[
                const SizedBox(height: 20),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  overflowAlignment: OverflowBarAlignment.end,
                  overflowSpacing: 8,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
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

class _IOSGlassPill extends StatelessWidget {
  final Widget child;
  final bool primary;
  const _IOSGlassPill({required this.child, required this.primary});

  @override
  Widget build(BuildContext context) {
    if (!usesIOSLiquidGlass) return child;
    return LiquidGlassContainer(
      shape: const LiquidGlassShape.capsule(),
      style: LiquidGlassStyle.regular,
      tint: primary ? const Color(0x405500ff) : null,
      interactive: false,
      child: child,
    );
  }
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
      final controller = ControllerFocus.activeOf(context);
      final hover =
          enabled &&
          (states.value.contains(WidgetState.hovered) ||
              (controller && states.value.contains(WidgetState.focused)));
      final focus = enabled && states.value.contains(WidgetState.focused);
      final pressed = enabled && states.value.contains(WidgetState.pressed);
      final duration = Duration(milliseconds: reduced ? 0 : 550);
      return ControllerFocusTarget(
        outline: false,
        child: AnimatedScale(
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
            child: _IOSGlassPill(
              primary: widget.primary,
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
                      backgroundBuilder: usesIOSLiquidGlass
                          ? _buttonLayerPassthrough
                          : null,
                      fixedSize: widget.iconOnly
                          ? WidgetStatePropertyAll(Size.square(widget.height))
                          : null,
                      minimumSize: WidgetStatePropertyAll(
                        Size(
                          widget.iconOnly ? widget.height : 0,
                          widget.height,
                        ),
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
                            : widget.primary && !usesIOSLiquidGlass
                            ? const Color(0xff19131f)
                            : const Color(0xfff8f7fa),
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => usesIOSLiquidGlass
                            ? Colors.transparent
                            : widget.primary
                            ? (hover
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
                          width: focus && !controller && widget.backStyle
                              ? 2
                              : 1,
                          color: focus && !controller
                              ? Colors.white
                              : hover
                              ? const Color(0x60ffffff)
                              : widget.primary && !usesIOSLiquidGlass
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
                            // The track already owns the native glass layer.
                            backgroundBuilder: usesIOSLiquidGlass
                                ? _buttonLayerPassthrough
                                : null,
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
                                      (s.contains(WidgetState.hovered) ||
                                          s.contains(WidgetState.focused))
                                  ? const Color(0x16ffffff)
                                  : Colors.transparent,
                            ),
                            side: WidgetStateProperty.resolveWith(
                              (s) => BorderSide(
                                color:
                                    s.contains(WidgetState.focused) &&
                                        !ControllerFocus.activeOf(context)
                                    ? Colors.white
                                    : Colors.transparent,
                              ),
                            ),
                            foregroundColor: WidgetStateProperty.resolveWith(
                              (s) => selected == mode
                                  ? const Color(0xff1a1420)
                                  : s.contains(WidgetState.hovered) ||
                                        s.contains(WidgetState.focused)
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

/// Shared release marker above the app wordmark or compact symbol.
class BetaBrand extends StatelessWidget {
  final double width;
  final bool compact;
  const BetaBrand({super.key, this.width = 120, this.compact = false});
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Image.asset(
        compact ? 'assets/brand/symbol.png' : 'assets/brand/wordmark.png',
        width: width,
        height: compact ? width : null,
      ),
      const Positioned(
        left: 0,
        top: -13,
        child: ExcludeSemantics(
          child: Text(
            'BETA',
            style: TextStyle(fontSize: 8, letterSpacing: 1.4, color: muted),
          ),
        ),
      ),
    ],
  );
}
