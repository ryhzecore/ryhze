import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design.dart';

class DesktopWindowScope extends InheritedWidget {
  final ValueChanged<bool> setFullscreen;
  const DesktopWindowScope({
    super.key,
    required this.setFullscreen,
    required super.child,
  });
  static DesktopWindowScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesktopWindowScope>();
  @override
  bool updateShouldNotify(DesktopWindowScope oldWidget) => false;
}

class DesktopWindow extends StatefulWidget {
  final Widget child;
  final bool initialFullscreen;
  const DesktopWindow({
    super.key,
    required this.child,
    this.initialFullscreen = false,
  });
  static const channel = MethodChannel('ryhze/desktop');
  @override
  State<DesktopWindow> createState() => _DesktopWindowState();
}

class _DesktopWindowState extends State<DesktopWindow>
    with WidgetsBindingObserver {
  final revision = ValueNotifier(0);
  bool attached = false;
  late final entry = OverlayEntry(
    builder: (context) => ValueListenableBuilder(
      valueListenable: revision,
      builder: (context, _, _) => frame(context),
    ),
  );
  late bool fullscreen = widget.initialFullscreen;
  bool maximized = false;
  bool get supported =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() async {
    if (!supported) return;
    try {
      final state = await DesktopWindow.channel
          .invokeMapMethod<String, dynamic>('state');
      final value = state?['maximized'];
      if (mounted && value is bool && value != maximized) {
        maximized = value;
        revision.value++;
      }
    } on MissingPluginException {
      // No native window in widget tests.
    } on PlatformException {
      // Resizing must remain usable if the platform cannot report its state.
    }
  }

  Future<void> command(String method) async {
    try {
      await DesktopWindow.channel.invokeMethod<void>(method);
      if (method == 'maximize' && mounted) {
        final state = await DesktopWindow.channel
            .invokeMapMethod<String, dynamic>('state');
        if (!mounted) return;
        maximized = state?['maximized'] == true;
        revision.value++;
      }
    } on MissingPluginException {
      // Widget previews do not own a desktop window.
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Window action is unavailable.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!supported) return widget.child;
    attached = true;
    return Overlay(initialEntries: [entry]);
  }

  @override
  void didUpdateWidget(DesktopWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    revision.value++;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (attached) entry.remove();
    entry.dispose();
    revision.dispose();
    super.dispose();
  }

  Widget frame(BuildContext context) {
    return DesktopWindowScope(
      setFullscreen: (value) {
        if (mounted && value != fullscreen) {
          fullscreen = value;
          revision.value++;
        }
      },
      child: ColoredBox(
        color: canvas,
        child: Column(
          children: [
            if (!fullscreen)
              SizedBox(
                height: 36,
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        key: const ValueKey('window-drag-region'),
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (_) => command('startDrag'),
                        onDoubleTap: () => command('maximize'),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    for (final action in [
                      ('Minimize', Icons.remove, 'minimize'),
                      (
                        maximized ? 'Restore window' : 'Maximize',
                        maximized ? Icons.filter_none : Icons.crop_square,
                        'maximize',
                      ),
                      ('Close Ryhze', Icons.close, 'close'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: IconButton(
                          tooltip: action.$1,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 28,
                            height: 28,
                          ),
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          style: IconButton.styleFrom(
                            shape: const CircleBorder(),
                          ),
                          onPressed: () => command(action.$3),
                          icon: Icon(action.$2),
                        ),
                      ),
                    const SizedBox(width: 10),
                  ],
                ),
              ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }
}
