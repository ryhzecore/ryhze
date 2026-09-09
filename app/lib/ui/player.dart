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
  const RyhzePlayer({
    super.key,
    required this.title,
    required this.state,
    this.heroTag,
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
  String? current, error;
  bool started = false, loading = false, full = false;
  List<String> get streams => widget.title.seasons.isEmpty
      ? widget.title.streams
      : widget.title.seasons[season].episodes.isEmpty
      ? []
      : widget.title.seasons[season].episodes[episode].streams;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final previous = widget.state.history[widget.title.id]?['stream'];
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
    if (player != null && current != null) {
      await widget.state.progress(
        widget.title.id,
        current!,
        player!.state.position,
        player!.state.duration,
      );
    }
  }

  Future<void> play([String? stream]) async {
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
        saveTimer = Timer.periodic(
          const Duration(seconds: 10),
          (_) => persist(),
        );
      }
      current = stream ?? streams.first;
      final uri = widget.state.api.media(current!);
      await player!.open(
        Media(uri.toString(), httpHeaders: widget.state.api.authHeaders),
        play: false,
      );
      final previous = widget.state.history[widget.title.id];
      if (previous != null &&
          previous['stream'] == current &&
          previous['position'] < previous['duration'] - 15) {
        await player!.seek(Duration(seconds: previous['position']));
      }
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
    WidgetsBinding.instance.removeObserver(this);
    saveTimer?.cancel();
    for (final s in subscriptions) {
      s.cancel();
    }
    persist();
    player?.dispose();
    super.dispose();
  }

  Widget picture() => Container(
    color: Colors.black,
    child: started && controller != null
        ? Video(controller: controller!, controls: NoVideoControls)
        : TitleArt(widget.title.image, widget.state, fit: BoxFit.cover),
  );
  Widget frame() => ClipRSuperellipse(
    borderRadius: BorderRadius.circular(surfaceRadius),
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: full ? const ColoredBox(color: Colors.black) : picture(),
    ),
  );
  Future<void> fullscreen() async {
    if (!started) return;
    setState(() => full = true);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.pop(context),
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(child: picture()),
                  controls(),
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
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.space): () {
        if (started) player?.playOrPause();
      },
      const SingleActivator(LogicalKeyboardKey.arrowRight): () {
        if (started) {
          player?.seek(player!.state.position + const Duration(seconds: 10));
        }
      },
    },
    child: Focus(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.heroTag != null)
            ArtworkHero(
              tag: widget.heroTag!,
              image: widget.title.image,
              state: widget.state,
              child: frame(),
            )
          else
            frame(),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 12),
          if (started && !full)
            controls()
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (streams.isNotEmpty)
                  Pill(
                    widget.state.history.containsKey(widget.title.id)
                        ? 'Continue watching'
                        : 'Play',
                    icon: Icons.play_arrow,
                    primary: true,
                    onPressed: loading ? null : () => play(),
                  )
                else
                  const Text(
                    'This video is not available yet.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                if (widget.title.preview != null)
                  Pill(
                    'Watch trailer',
                    icon: Icons.play_arrow_outlined,
                    onPressed: () => play(widget.title.preview),
                  ),
              ],
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
                    style: const TextStyle(color: Color(0xffffb4bb)),
                  ),
                  Pill('Try again', onPressed: () => play(current)),
                ],
              ),
            ),
          if (widget.title.seasons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButton<int>(
                    value: season,
                    items: [
                      for (var i = 0; i < widget.title.seasons.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(widget.title.seasons[i].title),
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
                    i < widget.title.seasons[season].episodes.length;
                    i++
                  )
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        widget.title.seasons[season].episodes[i].title,
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
            DropdownButton<String>(
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
        ],
      ),
    ),
  );
}
