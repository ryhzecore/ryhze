import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design.dart';
import 'expanding_surface.dart';
import 'controller_focus.dart';

/// Shared option rows: text responds to hover/focus without a filled highlight.
class RyhzeMenuItem<T> extends PopupMenuItem<T> {
  final bool? checked;
  const RyhzeMenuItem({
    super.key,
    super.value,
    super.onTap,
    super.enabled,
    super.height,
    super.padding,
    required super.child,
    this.checked,
  });

  @override
  PopupMenuItemState<T, RyhzeMenuItem<T>> createState() => _OptionState<T>();
}

class _OptionState<T> extends PopupMenuItemState<T, RyhzeMenuItem<T>> {
  bool hovered = false, focused = false;
  @override
  Widget buildChild() => AnimatedDefaultTextStyle(
    key: ValueKey('menu-option-${widget.value}'),
    duration: const Duration(milliseconds: 160),
    style: DefaultTextStyle.of(context).style.copyWith(
      fontSize: 14,
      color: !widget.enabled
          ? const Color(0xff77737e)
          : hovered || focused
          ? Colors.white
          : muted,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.checked != null) ...[
          Icon(widget.checked! ? Icons.check : null, size: 16),
          const SizedBox(width: 12),
        ],
        Flexible(child: widget.child!),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ControllerFocusTarget(
    outline: false,
    child: MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (value) => setState(() => focused = value),
        child: super.build(context),
      ),
    ),
  );
}

/// The same overlapping framed menu for category, season, source and subtitles.
class RyhzeDropdown<T> extends StatefulWidget {
  final T? value;
  final Widget? hint;
  final bool isExpanded;
  final bool fullWidthMenu;
  final InputDecoration decoration;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  const RyhzeDropdown({
    super.key,
    this.value,
    this.hint,
    this.isExpanded = false,
    this.fullWidthMenu = false,
    this.decoration = const InputDecoration(),
    required this.items,
    this.onChanged,
  });

  @override
  State<RyhzeDropdown<T>> createState() => _RyhzeDropdownState<T>();
}

class _RyhzeDropdownState<T> extends State<RyhzeDropdown<T>> {
  final anchor = GlobalKey();
  final focus = FocusNode();
  bool open = false;
  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  Future<void> showOptions() async {
    if (open || widget.onChanged == null) return;
    final box = anchor.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    open = true;
    final options = widget.items;
    final selected = options.indexWhere(
      (item) => item.value == widget.value && item.enabled,
    );
    final initial = selected >= 0
        ? selected
        : options.indexWhere((item) => item.enabled);
    final scroll = ScrollController(
      initialScrollOffset: initial > 0 ? initial * 48.0 : 0,
    );
    try {
      final result = await expandingSurface<T>(
        context: context,
        source: anchor,
        icon: Icons.keyboard_arrow_down,
        width: box.size.width,
        height: (options.length * 48.0 + 16).clamp(64, 420),
        anchorToSource: true,
        builder: (menuContext) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.pop(menuContext),
          },
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
              SingleActivator(LogicalKeyboardKey.arrowUp):
                  PreviousFocusIntent(),
            },
            child: FocusTraversalGroup(
              child: ListView(
                key: const ValueKey('full-width-options'),
                controller: scroll,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (var i = 0; i < options.length; i++)
                    SizedBox(
                      height: 48,
                      child: TextButton(
                        autofocus: i == initial,
                        onPressed: options[i].enabled
                            ? () => Navigator.pop(menuContext, options[i].value)
                            : null,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: options[i].child,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      if (mounted && result != null) widget.onChanged?.call(result);
    } finally {
      scroll.dispose();
      open = false;
      if (mounted) focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final items = widget.items;
    final isExpanded = widget.isExpanded;
    final onChanged = widget.onChanged;
    final selected = items.where((item) => item.value == value).firstOrNull;
    final label = selected?.child ?? widget.hint ?? const Text('Choose');
    final control = InputDecorator(
      decoration: widget.decoration,
      child: Row(
        mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (isExpanded) Expanded(child: label) else label,
          const SizedBox(width: 12),
          const Icon(Icons.keyboard_arrow_down, size: 20),
        ],
      ),
    );
    if (widget.fullWidthMenu) {
      return Semantics(
        button: true,
        enabled: onChanged != null,
        child: InkWell(
          key: anchor,
          focusNode: focus,
          onTap: onChanged == null ? null : showOptions,
          borderRadius: BorderRadius.circular(popoverRadius),
          child: control,
        ),
      );
    }
    return PopupMenuButton<T>(
      enabled: onChanged != null,
      initialValue: value,
      position: PopupMenuPosition.over,
      clipBehavior: Clip.antiAlias,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final item in items)
          RyhzeMenuItem<T>(
            value: item.value,
            enabled: item.enabled,
            child: item.child,
          ),
      ],
      child: InputDecorator(
        decoration: widget.decoration,
        child: Row(
          mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (isExpanded) Expanded(child: label) else label,
            const SizedBox(width: 12),
            const Icon(Icons.keyboard_arrow_down, size: 20),
          ],
        ),
      ),
    );
  }
}
