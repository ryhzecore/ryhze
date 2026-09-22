import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'controller_focus.dart';

/// Adds fullscreen and controller input to the regular Ryhze interface.
class BigPicture extends StatefulWidget {
  static const channel = MethodChannel('ryhze/desktop');
  final Widget child;
  final VoidCallback onExit;
  final bool Function()? onBack;
  const BigPicture({
    super.key,
    required this.child,
    required this.onExit,
    this.onBack,
  });
  @override
  State<BigPicture> createState() => _BigPictureState();
}

class _BigPictureState extends State<BigPicture> {
  bool exitOpen = false;
  final inputClock = Stopwatch()..start();
  TraversalDirection? lastDirection;
  bool? lastWasController;
  int lastMove = -1000;

  void navigate(TraversalDirection direction, {required bool controller}) {
    final now = inputClock.elapsedMilliseconds;
    // Steam's desktop mapping can accompany an SDL direction with an arrow
    // key. Consume that paired report once, in either arrival order, while
    // preserving rapid separate presses from the same input source.
    if (direction == lastDirection &&
        lastWasController != controller &&
        now - lastMove < 100) {
      return;
    }
    lastDirection = direction;
    lastWasController = controller;
    lastMove = now;
    final target = FocusManager.instance.primaryFocus?.context;
    if (target != null) {
      Actions.maybeInvoke(target, DirectionalFocusIntent(direction));
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(nativeMode(true));
    BigPicture.channel.setMethodCallHandler((call) async {
      if (call.method != 'controller' || !mounted) return;
      final target = FocusManager.instance.primaryFocus?.context;
      final direction = switch (call.arguments) {
        'left' => TraversalDirection.left,
        'right' => TraversalDirection.right,
        'up' => TraversalDirection.up,
        'down' => TraversalDirection.down,
        _ => null,
      };
      if (direction != null && target != null) {
        navigate(direction, controller: true);
      } else if (call.arguments == 'select' && target != null) {
        Actions.maybeInvoke(target, const ActivateIntent());
      } else if (call.arguments == 'back') {
        await back();
      }
    });
  }

  Future<void> nativeMode(bool enabled) async {
    try {
      await BigPicture.channel.invokeMethod<void>('bigPicture', enabled);
    } on MissingPluginException {
      // Tests and non-Linux previews have no GTK window.
    } on PlatformException catch (error) {
      if (mounted && enabled) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('Fullscreen could not open: ${error.message}'),
          ),
        );
      }
    }
  }

  Future<void> back() async {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      await navigator.maybePop();
      return;
    }
    if (widget.onBack?.call() == true) return;
    if (exitOpen) return;
    exitOpen = true;
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Big Picture?'),
        content: const Text(
          'Return to the regular Ryhze window in Desktop Mode.',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit Big Picture'),
          ),
        ],
      ),
    );
    exitOpen = false;
    if (exit == true && mounted) widget.onExit();
  }

  @override
  void dispose() {
    BigPicture.channel.setMethodCallHandler(null);
    unawaited(nativeMode(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): back,
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
          navigate(TraversalDirection.left, controller: false),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
          navigate(TraversalDirection.right, controller: false),
      const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
          navigate(TraversalDirection.up, controller: false),
      const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
          navigate(TraversalDirection.down, controller: false),
    },
    child: ControllerFocus(child: widget.child),
  );
}
