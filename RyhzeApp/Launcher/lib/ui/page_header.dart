import 'package:flutter/material.dart';
import 'design.dart';

/// The same spacing, canvas and circular actions as the browsing header.
class RyhzePageHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool compact;
  final List<Widget> actions;
  const RyhzePageHeader({
    super.key,
    required this.title,
    required this.compact,
    this.actions = const [],
  });

  @override
  Size get preferredSize => Size.fromHeight(compact ? 88 : 104);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = width <= 350
        ? 16.0
        : compact
        ? 22.0
        : (width * .045).clamp(20.0, 88.0);
    return IOSGlassChrome(
      radius: 0,
      child: ColoredBox(
        color: usesIOSLiquidGlass ? Colors.transparent : canvas,
        child: SafeArea(
          bottom: false,
          child: Container(
            height: preferredSize.height,
            padding: EdgeInsets.symmetric(horizontal: gutter),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x0cffffff))),
            ),
            child: Row(
              children: [
                Pill(
                  'Back',
                  icon: Icons.arrow_back,
                  iconOnly: true,
                  height: compact ? 44 : 48,
                  onPressed: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    style: heading(compact ? 20 : 24),
                  ),
                ),
                for (final action in actions) ...[
                  const SizedBox(width: 12),
                  action,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
