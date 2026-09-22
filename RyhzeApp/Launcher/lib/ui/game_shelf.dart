import 'package:flutter/material.dart';
import 'design.dart';

/// The regular app cards in a controller-friendly horizontal row.
class GameShelf extends StatefulWidget {
  final List<Widget> children;
  const GameShelf({super.key, required this.children});
  @override
  State<GameShelf> createState() => _GameShelfState();
}

class _GameShelfState extends State<GameShelf> {
  final nodes = <Key, FocusNode>{};
  int selected = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.children.isNotEmpty &&
          ModalRoute.of(context)?.isCurrent == true) {
        node(0).requestFocus();
      }
    });
  }

  Key identity(int i) => widget.children[i].key ?? ValueKey(i);
  FocusNode node(int i) => nodes.putIfAbsent(
    identity(i),
    () => FocusNode(debugLabel: 'Game shelf ${identity(i)}'),
  );
  void move(int delta) {
    if (widget.children.isEmpty) return;
    final next = (selected + delta).clamp(0, widget.children.length - 1);
    // Focus notifications arrive later; successive real presses must advance
    // from the requested card instead of reusing a stale selection.
    selected = next;
    node(next).requestFocus();
  }

  @override
  void didUpdateWidget(covariant GameShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    final keys = {for (var i = 0; i < widget.children.length; i++) identity(i)};
    for (final key in nodes.keys.where((key) => !keys.contains(key)).toList()) {
      nodes.remove(key)!.dispose();
    }
    selected = selected.clamp(
      0,
      widget.children.isEmpty ? 0 : widget.children.length - 1,
    );
  }

  @override
  void dispose() {
    for (final node in nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final width = (bounds.maxWidth / 3.6).clamp(240.0, 360.0);
      final reduced = MotionSettings.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Actions(
            actions: {
              DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(
                onInvoke: (intent) {
                  if (intent.direction == TraversalDirection.left ||
                      intent.direction == TraversalDirection.right) {
                    move(intent.direction == TraversalDirection.left ? -1 : 1);
                  } else {
                    FocusManager.instance.primaryFocus?.focusInDirection(
                      intent.direction,
                    );
                  }
                  return null;
                },
              ),
            },
            child: SingleChildScrollView(
              key: const ValueKey('big-picture-game-row'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < widget.children.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        right: i == widget.children.length - 1 ? 0 : 24,
                      ),
                      child: SizedBox(
                        width: width,
                        child: Builder(
                          builder: (itemContext) => Focus(
                            canRequestFocus: false,
                            onFocusChange: (focused) {
                              if (!focused) return;
                              setState(() => selected = i);
                              Scrollable.of(
                                itemContext,
                                axis: Axis.horizontal,
                              ).position.ensureVisible(
                                itemContext.findRenderObject()!,
                                alignment: .5,
                                duration: Duration(
                                  milliseconds: reduced ? 0 : 260,
                                ),
                                curve: ryhzeEase,
                              );
                            },
                            child: GameShelfItem(
                              focusNode: node(i),
                              autofocus: i == 0,
                              child: widget.children[i],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (widget.children.isNotEmpty)
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '← / →  Browse     A / Enter  Open     B / Esc  Back',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ),
                Pill(
                  'Previous game',
                  icon: Icons.chevron_left,
                  iconOnly: true,
                  quiet: true,
                  onPressed: selected > 0 ? () => move(-1) : null,
                ),
                const SizedBox(width: 8),
                Pill(
                  'Next game',
                  icon: Icons.chevron_right,
                  iconOnly: true,
                  quiet: true,
                  onPressed: selected + 1 < widget.children.length
                      ? () => move(1)
                      : null,
                ),
              ],
            ),
        ],
      );
    },
  );
}

class GameShelfItem extends InheritedWidget {
  final FocusNode focusNode;
  final bool autofocus;
  const GameShelfItem({
    super.key,
    required this.focusNode,
    required this.autofocus,
    required super.child,
  });
  static GameShelfItem? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameShelfItem>();
  @override
  bool updateShouldNotify(GameShelfItem oldWidget) =>
      focusNode != oldWidget.focusNode || autofocus != oldWidget.autofocus;
}
