import 'option_menu.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../core/models.dart';
import '../core/state.dart';
import 'design.dart';
import 'playback_bar.dart';
import 'artwork_hero.dart';

class RyhzePlayer extends StatefulWidget {
  final RyhzeTitle title;
  final RyhzeState state;
  final String? heroTag;
  final bool recordProgress;
  final bool Function()? canPlay;
  final Widget? poster;
  final double? frameAspectRatio;
  const RyhzePlayer({
    super.key,
    required this.title,
    required this.state,
    this.heroTag,
    this.recordProgress = true,
    this.canPlay,
    this.poster,
    this.frameAspectRatio,
  });
  @override
  State<RyhzePlayer> createState() => _RyhzePlayerState();
}

class _RyhzePlayerState extends State<RyhzePlayer> with WidgetsBindingObserver {
  Player? player;
  VideoController? controller;
  final subscriptions = <StreamSubscription>[];
  Timer? saveTimer;
  int season = 0, episode = 0;
  int _attempt = 0;
  String? current, error;
  bool started = false, loading = false, full = false;
  bool get allowed => widget.canPlay?.call() ?? true;
  void accessChanged() {
    if (!mounted || allowed) return;
    _attempt++;
    final active = player;
    if (active != null) unawaited(active.stop().catchError((_) {}));
    setState(() {
      started = false;
      loading = false;
      error = 'Playback access is no longer available.';
    });
  }

  List<String> get streams => widget.title.seasons.isEmpty
      ? widget.title.streams
      : widget.title.seasons[season].episodes.isEmpty
      ? []
      : widget.title.seasons[season].episodes[episode].streams;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.state.addListener(accessChanged);
    final previous = widget.recordProgress
        ? (widget.state.history[widget.title.id]?['stream'])
        : null;
    if (previous is String) {
      for (var s = 0; s < widget.title.seasons.length; s++) {
        for (var e = 0; e < widget.title.seasons[s].episodes.length; e++) {
          if (widget.title.seasons[s].episodes[e].streams.contains(previous)) {
            season = s;
            episode = e;
          }
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      player?.pause();
      persist();
    }
  }

  Future<void> persist() async {
    if (widget.recordProgress && player != null && current != null) {
      await widget.state.progress(
        widget.title.id,
        current!,
        player!.state.position,
        player!.state.duration,
      );
    }
  }

  Future<void> play([String? stream]) async {
    if (loading || !allowed) return;
    final attempt = ++_attempt;
    if (streams.isEmpty && stream == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      player ??= Player();
      controller ??= VideoController(player!);
      if (subscriptions.isEmpty) {
        subscriptions.add(
          player!.stream.error.listen((value) {
            if (mounted) {
              setState(() {
                error =
                    'Playback interrupted. Check your connection or try another source.';
                loading = false;
              });
            }
          }),
        );
        subscriptions.add(
          player!.stream.buffering.listen((v) {
            if (mounted) setState(() => loading = v);
          }),
        );
        if (widget.recordProgress) {
          saveTimer = Timer.periodic(
            const Duration(seconds: 10),
            (_) => persist(),
          );
        }
      }
      current = stream ?? streams.first;
      final uri = widget.state.api.media(current!);
      await player!.open(
        Media(uri.toString(), httpHeaders: widget.state.api.authHeaders),
        play: false,
      );
      if (!mounted || !allowed || attempt != _attempt) return;
      final previous = widget.recordProgress
          ? widget.state.history[widget.title.id]
          : null;
      if (previous != null &&
          previous['watched'] != true &&
          previous['stream'] == current &&
          previous['position'] < previous['duration'] * .95) {
        await player!.seek(
          Duration(
            milliseconds: ((previous['position'] as num) * 1000).round(),
          ),
        );
      }
      if (!mounted || !allowed || attempt != _attempt) return;
      await player!.play();
      if (mounted) {
        setState(() {
          started = true;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error =
              'This video could not be opened. Sign in again or try another source.';
          loading = false;
        });
      }
    }
  }

  Future<void> stop() async {
    _attempt++;
    await persist();
    await player?.pause();
    if (mounted) {
      setState(() {
        started = false;
        error = null;
      });
    }
  }

  @override
  void dispose() {
    _attempt++;
    WidgetsBinding.instance.removeObserver(this);
    widget.state.removeListener(accessChanged);
    saveTimer?.cancel();
    for (final s in subscriptions) {
      s.cancel();
    }
    persist();
    player?.dispose();
    super.dispose();
  }

  String get playLabel =>
      widget.recordProgress &&
          widget.state.history[widget.title.id]?['watched'] != true &&
          (widget.state.history[widget.title.id]?['position'] ?? 0) > 0
      ? 'Continue watching'
      : 'Play';
  Widget picture() => Stack(
    fit: StackFit.expand,
    children: [
      ColoredBox(
        color: Colors.black,
        child: started && controller != null
            ? Video(controller: controller!, controls: NoVideoControls)
            : widget.poster ??
                  TitleArt(widget.title.image, widget.state, fit: BoxFit.cover),
      ),
      if (started) ...[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: () => player?.playOrPause(),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 24, 12, 4),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xe6000000)],
              ),
            ),
            child: controls(),
          ),
        ),
      ] else if (streams.isNotEmpty)
        Center(
          child: Pill(
            playLabel,
            icon: Icons.play_arrow,
            primary: true,
            onPressed: loading ? null : () => play(),
          ),
        ),
    ],
  );
  Widget frame() => ClipRSuperellipse(
    borderRadius: BorderRadius.circular(surfaceRadius),
    child: AspectRatio(
      aspectRatio:
          widget.frameAspectRatio ??
          (started
              ? 16 / 9
              : artworkAspectRatio(MediaQuery.sizeOf(context).width)),
      child: full ? const ColoredBox(color: Colors.black) : picture(),
    ),
  );
  Future<void> fullscreen() async {
    if (!started || !allowed) return;
    final playbackState = widget.state;
    final playbackPermission = widget.canPlay;
    setState(() => full = true);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ListenableBuilder(
          listenable: playbackState,
          builder: (context, _) => CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  Navigator.pop(context),
            },
            child: Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: mounted && (playbackPermission?.call() ?? true)
                          ? picture()
                          : const Center(
                              child: Text(
                                'Playback access is no longer available.',
                              ),
                            ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Exit full screen'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() => full = false);
  }

  String time(Duration duration) =>
      '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  Widget controls() => player == null
      ? const SizedBox.shrink()
      : PlaybackBar(
          player: player!,
          fullscreen: full,
          onFullscreen: () {
            if (full) {
              Navigator.pop(context);
            } else {
              fullscreen();
            }
          },
          onStop: () {
            if (full) Navigator.pop(context);
            stop();
          },
        );

  @override
  Widget build(BuildContext context) => !allowed
      ? const Text('Playback access is no longer available.')
      : CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.space): () {
              if (started) player?.playOrPause();
            },
            const SingleActivator(LogicalKeyboardKey.arrowRight): () {
              if (started) {
                player?.seek(
                  player!.state.position + const Duration(seconds: 10),
                );
              }
            },
          },
          child: Focus(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children:
                  [
                        if (widget.heroTag != null)
                          ArtworkHero(
                            tag: widget.heroTag!,
                            image: widget.title.image,
                            state: widget.state,
                            child: frame(),
                          )
                        else
                          frame(),
                        if (loading)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: StatusProgress(label: 'Loading video'),
                          ),
                        if (!started && streams.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'This video is not available yet.',
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                          ),
                        if (!started && widget.title.preview != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Pill(
                                'Watch trailer',
                                icon: Icons.play_arrow_outlined,
                                onPressed: () => play(widget.title.preview),
                              ),
                            ),
                          ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Wrap(
                              spacing: 16,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  error!,
                                  style: const TextStyle(
                                    color: Color(0xffffb4bb),
                                  ),
                                ),
                                Pill(
                                  'Try again',
                                  onPressed: () => play(current),
                                ),
                              ],
                            ),
                          ),
                        if (widget.title.seasons.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RyhzeDropdown<int>(
                                  value: season,
                                  items: [
                                    for (
                                      var i = 0;
                                      i < widget.title.seasons.length;
                                      i++
                                    )
                                      DropdownMenuItem(
                                        value: i,
                                        child: Text(
                                          widget.title.seasons[i].title,
                                        ),
                                      ),
                                  ],
                                  onChanged: (i) async {
                                    if (i != null) {
                                      await stop();
                                      setState(() {
                                        season = i;
                                        episode = 0;
                                      });
                                    }
                                  },
                                ),
                                for (
                                  var i = 0;
                                  i <
                                      widget
                                          .title
                                          .seasons[season]
                                          .episodes
                                          .length;
                                  i++
                                )
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      widget
                                          .title
                                          .seasons[season]
                                          .episodes[i]
                                          .title,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    leading: Icon(
                                      i == episode && started
                                          ? Icons.equalizer
                                          : Icons.play_circle_outline,
                                    ),
                                    onTap: () async {
                                      await stop();
                                      setState(() => episode = i);
                                      await play();
                                    },
                                  ),
                              ],
                            ),
                          ),
                        if (streams.length > 1)
                          RyhzeDropdown<String>(
                            hint: const Text('Playback source'),
                            value: streams.contains(current) ? current : null,
                            items: [
                              for (var i = 0; i < streams.length; i++)
                                DropdownMenuItem(
                                  value: streams[i],
                                  child: Text('Source ${i + 1}'),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) play(v);
                            },
                          ),
                      ]
                      .map(
                        (item) =>
                            item is ArtworkHero || item is ClipRSuperellipse
                            ? item
                            : DetailControlsReveal(child: item),
                      )
                      .toList(),
            ),
          ),
        );
}
