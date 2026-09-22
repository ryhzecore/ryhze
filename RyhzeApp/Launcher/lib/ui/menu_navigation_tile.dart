import 'package:flutter/material.dart';
import 'controller_focus.dart';

class MenuNavigationTile extends StatefulWidget {
  final String label;
  final bool controller, autofocus, reduced;
  final VoidCallback onTap;
  const MenuNavigationTile({
    super.key,
    required this.label,
    required this.onTap,
    this.controller = false,
    this.autofocus = false,
    this.reduced = false,
  });
  @override
  State<MenuNavigationTile> createState() => _MenuNavigationTileState();
}

class _MenuNavigationTileState extends State<MenuNavigationTile> {
  final focus = FocusNode();
  bool hovered = false;
  @override
  void initState() {
    super.initState();
    focus.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    focus.removeListener(changed);
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.controller && (focus.hasFocus || hovered);
    return ControllerFocusTarget(
      outline: false,
      child: MouseRegion(
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: ListTile(
          focusNode: focus,
          autofocus: widget.autofocus,
          contentPadding: EdgeInsets.zero,
          focusColor: widget.controller ? Colors.transparent : null,
          hoverColor: widget.controller ? Colors.transparent : null,
          title: AnimatedDefaultTextStyle(
            duration: Duration(milliseconds: widget.reduced ? 0 : 160),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: selected
                  ? const Color(0xffd6c3ff)
                  : const Color(0xfff8f7fa),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              shadows: selected
                  ? const [Shadow(color: Color(0xaa5500ff), blurRadius: 10)]
                  : const [],
            ),
            child: Text(widget.label),
          ),
          trailing: Icon(
            Icons.arrow_forward,
            size: 18,
            color: selected ? const Color(0xffd6c3ff) : null,
          ),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}
