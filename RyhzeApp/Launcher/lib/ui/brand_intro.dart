import 'dart:async';
import 'dart:math' show sin, pi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'design.dart';

/// One introduction per mounted app session; navigation does not replay it.
class BrandIntro extends StatefulWidget {
  final bool sound, reduced, ready;
  final Widget Function(bool playing) builder;
  const BrandIntro({
    super.key,
    required this.builder,
    this.ready = true,
    this.sound = true,
    this.reduced = false,
  });
  @override
  State<BrandIntro> createState() => _BrandIntroState();
}

class _BrandIntroState extends State<BrandIntro>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController timeline;
  Player? audio;
  bool showing = true, minimumElapsed = false, started = false, zooming = false;
  Timer? loadingDelay, audioTail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timeline =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 700),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && zooming) {
            finish(allowAudioTail: true);
          }
        });
    loadingDelay = Timer(const Duration(seconds: 3), () {
      minimumElapsed = true;
      if (mounted) unawaited(start());
    });
  }

  @override
  void didUpdateWidget(BrandIntro oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready && !oldWidget.ready) unawaited(start());
  }

  Future<void> start() async {
    if (!mounted || !showing || started || !minimumElapsed || !widget.ready) {
      return;
    }
    started = true;
    if (widget.sound) {
      try {
        final player = audio = Player();
        await player.setVolume(60);
        await player
            .open(
              Media('asset:///assets/audio/brand-intro-v4.mp3'),
              play: false,
            )
            .timeout(const Duration(milliseconds: 700));
        if (!mounted || !showing) return;
      } catch (_) {
        // Audio is optional; an unavailable device must not block startup.
        final player = audio;
        audio = null;
        if (player != null) unawaited(player.dispose());
      }
    }
    if (!mounted || !showing) return;
    try {
      await timeline.forward().orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted || !showing) return;
    // The preloaded audio and zoom share this single phase boundary.
    timeline.duration = const Duration(milliseconds: 900);
    setState(() => zooming = true);
    final player = audio;
    if (player != null) unawaited(player.play().catchError((Object _) {}));
    timeline.forward(from: 0);
  }

  void releaseAudio() {
    audioTail?.cancel();
    final player = audio;
    audio = null;
    if (player != null) unawaited(player.dispose());
  }

  void finish({bool allowAudioTail = false}) {
    if (!mounted) return;
    if (!showing) {
      releaseAudio();
      return;
    }
    loadingDelay?.cancel();
    timeline.stop();
    // Reveal quickly without cutting the brand recording short.
    if (allowAudioTail && audio != null) {
      audioTail = Timer(const Duration(seconds: 4), releaseAudio);
    } else {
      releaseAudio();
    }
    setState(() => showing = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      finish();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    loadingDelay?.cancel();
    audioTail?.cancel();
    timeline.dispose();
    audio?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.builder(showing);
    final reduced = widget.reduced || MediaQuery.disableAnimationsOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: showing,
          child: ExcludeSemantics(excluding: showing, child: child),
        ),
        if (showing)
          Focus(
            autofocus: true,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                finish();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: AnimatedBuilder(
              animation: timeline,
              builder: (context, _) {
                final reveal = zooming
                    ? Curves.easeOutCubic.transform(timeline.value)
                    : 0.0;
                final sheen = reduced || zooming ? 0.0 : timeline.value;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: 1 - reveal,
                      child: ColoredBox(
                        color: canvas,
                        child: CustomPaint(
                          key: const ValueKey('brand-intro-shine'),
                          painter: _BlackSheen(sheen),
                        ),
                      ),
                    ),
                    Center(
                      child: Opacity(
                        opacity: (1 - reveal).clamp(0.0, 1.0),
                        child: Transform.scale(
                          key: const ValueKey('brand-intro-logo'),
                          scale: reduced ? 1 : 1 + reveal * 13,
                          child: Image.asset(
                            'assets/brand/wordmark.png',
                            width: 220,
                            semanticLabel: 'Ryhze',
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 20,
                      bottom: 20,
                      child: SafeArea(
                        child: TextButton(
                          onPressed: finish,
                          child: const Text('Skip intro'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

/// A restrained specular reflection on black, painted without a gradient.
class _BlackSheen extends CustomPainter {
  final double progress;
  const _BlackSheen(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final strength = sin(pi * progress);
    final x = size.width * (-.35 + progress * 1.7);
    final reflection = Path()
      ..moveTo(x - size.width * .2, 0)
      ..cubicTo(
        x + size.width * .03,
        size.height * .3,
        x - size.width * .03,
        size.height * .7,
        x + size.width * .2,
        size.height,
      );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final pass in [(26.0, 22.0, .035), (2.0, 5.0, .07)]) {
      canvas.drawPath(
        reflection,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = pass.$1
          ..color = Colors.white.withValues(alpha: strength * pass.$3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, pass.$2),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BlackSheen oldDelegate) =>
      progress != oldDelegate.progress;
}
