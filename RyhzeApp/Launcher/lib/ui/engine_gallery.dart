import 'package:flutter/material.dart';
import '../core/state.dart';
import 'design.dart';
import 'engine_demo.dart';
import 'engine_versions.dart';

class EngineVersionGallery extends StatefulWidget {
  final RyhzeState state;
  final EngineBuild build;
  const EngineVersionGallery({
    super.key,
    required this.state,
    required this.build,
  });
  @override
  State<EngineVersionGallery> createState() => _EngineVersionGalleryState();
}

class _EngineVersionGalleryState extends State<EngineVersionGallery> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    final items = [
      if (widget.build.demo != null) widget.build.demo!.toJson(),
      ...widget.build.media,
    ];
    if (items.isEmpty || !widget.state.engineAccess) {
      return const SizedBox.shrink();
    }
    final item = items[selected.clamp(0, items.length - 1)];
    final ratio = artworkAspectRatio(MediaQuery.sizeOf(context).width);
    final video = item['mime'] == 'video/mp4';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.build.title.isEmpty ? 'Version media' : widget.build.title,
          style: heading(22),
        ),
        const SizedBox(height: 16),
        ClipRSuperellipse(
          borderRadius: BorderRadius.circular(surfaceRadius),
          child: AspectRatio(
            aspectRatio: ratio,
            child: video
                ? EngineDemoArtwork(
                    key: ValueKey(
                      '${widget.build.id}:${item['url']}:${widget.state.scope}',
                    ),
                    state: widget.state,
                    buildId: widget.build.id,
                    demo: EngineDemo.fromJson(item, widget.build.id),
                    poster: Container(
                      color: const Color(0xff17171d),
                      child: const Center(
                        child: Icon(Icons.play_circle_outline, size: 64),
                      ),
                    ),
                    aspectRatio: ratio,
                  )
                : TitleArt(item['url'], widget.state),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                '${selected + 2} / ${items.length + 1} · ${item['title'] ?? (video ? 'Video' : 'Image')}',
                style: const TextStyle(color: muted),
              ),
            ),
            Pill(
              'Previous version media',
              iconOnly: true,
              icon: Icons.chevron_left,
              onPressed: selected == 0
                  ? null
                  : () => setState(() => selected--),
            ),
            const SizedBox(width: 8),
            Pill(
              'Next version media',
              iconOnly: true,
              icon: Icons.chevron_right,
              onPressed: selected >= items.length - 1
                  ? null
                  : () => setState(() => selected++),
            ),
          ],
        ),
      ],
    );
  }
}
