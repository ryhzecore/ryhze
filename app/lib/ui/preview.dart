import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../core/models.dart';
import '../core/state.dart';
import 'design.dart';

class ArtworkPreview extends StatefulWidget {
  final RyhzeTitle title;
  final RyhzeState state;
  final bool active;
  const ArtworkPreview({
    super.key,
    required this.title,
    required this.state,
    this.active = false,
  });
  @override
  State<ArtworkPreview> createState() => _ArtworkPreviewState();
}

class _ArtworkPreviewState extends State<ArtworkPreview>
    with WidgetsBindingObserver {
  Timer? delay;
  Player? player;
  VideoController? video;
  StreamSubscription<String>? errors;
  bool visible = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) enter();
  }

  @override
  void didUpdateWidget(ArtworkPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active || widget.state.reduced) {
      leave();
    } else if (!oldWidget.active ||
        oldWidget.title.preview != widget.title.preview) {
      leave();
      enter();
    }
  }

  void enter() {
    if (widget.title.preview == null || widget.state.reduced) return;
    delay?.cancel();
    final ticket = ++generation;
    delay = Timer(const Duration(milliseconds: 600), () async {
      try {
        if (!mounted || ticket != generation) return;
        final url = widget.state.api.media(widget.title.preview!);
        final p = Player();
        player = p;
        errors = p.stream.error.listen((_) => leave());
        video = VideoController(p);
        await p.setVolume(0);
        if (!mounted || ticket != generation) return;
        await p.setPlaylistMode(PlaylistMode.single);
        if (!mounted || ticket != generation) return;
        await p.open(
          Media(url.toString(), httpHeaders: widget.state.api.authHeaders),
        );
        if (mounted && ticket == generation) setState(() => visible = true);
      } catch (_) {
        if (ticket == generation) leave();
      }
    });
  }

  void leave() {
    generation++;
    delay?.cancel();
    errors?.cancel();
    errors = null;
    final previous = player;
    player = null;
    video = null;
    previous?.dispose();
    if (mounted && visible) setState(() => visible = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      leave();
    } else if (widget.active) {
      enter();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    generation++;
    delay?.cancel();
    errors?.cancel();
    player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      TitleArt(widget.title.image, widget.state),
      if (visible && video != null)
        IgnorePointer(
          child: Video(
            controller: video!,
            fit: BoxFit.cover,
            controls: NoVideoControls,
          ),
        ),
    ],
  );
}
