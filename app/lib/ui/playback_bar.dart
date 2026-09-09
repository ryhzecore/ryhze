import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'design.dart';

class PlaybackBar extends StatelessWidget {
  final Player player;
  final bool fullscreen;
  final VoidCallback onFullscreen, onStop;
  const PlaybackBar({
    super.key,
    required this.player,
    required this.fullscreen,
    required this.onFullscreen,
    required this.onStop,
  });
  String time(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  void skip(int seconds) => player.seek(
    Duration(
      milliseconds: (player.state.position.inMilliseconds + seconds * 1000)
          .clamp(0, player.state.duration.inMilliseconds),
    ),
  );
  @override
  Widget build(BuildContext context) => StreamBuilder<Duration>(
    stream: player.stream.position,
    initialData: player.state.position,
    builder: (context, snapshot) => LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth <= 480;
        final maximum = player.state.duration.inMilliseconds
            .toDouble()
            .clamp(1.0, double.infinity)
            .toDouble();
        final timeLabel = Text(
          '${time(snapshot.data ?? Duration.zero)} / ${time(player.state.duration)}',
          style: TextStyle(fontSize: compact ? 9 : 10, height: 1.3),
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  StreamBuilder<bool>(
                    stream: player.stream.playing,
                    initialData: player.state.playing,
                    builder: (_, value) => Pill(
                      value.data == true ? 'Pause' : 'Play',
                      iconOnly: true,
                      quiet: true,
                      height: 44,
                      icon: value.data == true ? Icons.pause : Icons.play_arrow,
                      onPressed: player.playOrPause,
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      label: 'Playback position',
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                        ),
                        child: Slider(
                          value:
                              (snapshot.data?.inMilliseconds.toDouble() ?? 0.0)
                                  .clamp(0.0, maximum)
                                  .toDouble(),
                          max: maximum,
                          label: time(snapshot.data ?? Duration.zero),
                          onChanged: (v) =>
                              player.seek(Duration(milliseconds: v.toInt())),
                        ),
                      ),
                    ),
                  ),
                  if (!compact) ...[timeLabel, const SizedBox(width: 10)],
                  StreamBuilder<double>(
                    stream: player.stream.volume,
                    initialData: player.state.volume,
                    builder: (_, value) => Pill(
                      value.data == 0 ? 'Unmute' : 'Mute',
                      iconOnly: true,
                      quiet: true,
                      height: 44,
                      icon: value.data == 0
                          ? Icons.volume_off_outlined
                          : Icons.volume_up_outlined,
                      onPressed: () =>
                          player.setVolume(value.data == 0 ? 100 : 0),
                    ),
                  ),
                  Pill(
                    fullscreen ? 'Exit full screen' : 'Full screen',
                    iconOnly: true,
                    quiet: true,
                    height: 44,
                    icon: fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    onPressed: onFullscreen,
                  ),
                  Pill(
                    'Return to artwork',
                    iconOnly: true,
                    quiet: true,
                    height: 44,
                    icon: Icons.stop_circle_outlined,
                    onPressed: onStop,
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Playback options',
                    icon: const Icon(Icons.more_horiz, size: 20),
                    constraints: const BoxConstraints(
                      minWidth: 220,
                      maxWidth: 280,
                    ),
                    onSelected: (value) {
                      if (value == 'back') {
                        skip(-10);
                      } else if (value == 'forward') {
                        skip(10);
                      } else {
                        player.setRate(double.parse(value));
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'back',
                        child: Text('Back 10 seconds'),
                      ),
                      const PopupMenuItem(
                        value: 'forward',
                        child: Text('Forward 10 seconds'),
                      ),
                      const PopupMenuDivider(),
                      for (final rate in [.5, .75, 1.0, 1.25, 1.5, 2.0])
                        CheckedPopupMenuItem(
                          value: '$rate',
                          checked: player.state.rate == rate,
                          child: Text('Speed $rate×'),
                        ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        enabled: false,
                        child: StreamBuilder<double>(
                          stream: player.stream.volume,
                          initialData: player.state.volume,
                          builder: (context, volume) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Volume',
                                style: TextStyle(fontSize: 12),
                              ),
                              Slider(
                                value: (volume.data ?? 100).clamp(0, 100),
                                max: 100,
                                onChanged: player.setVolume,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (compact)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: timeLabel,
                ),
              StreamBuilder<Tracks>(
                stream: player.stream.tracks,
                initialData: player.state.tracks,
                builder: (_, value) {
                  final tracks =
                      value.data?.subtitle
                          .where((t) => t.id != 'auto')
                          .toList() ??
                      [];
                  if (tracks.length < 2) return const SizedBox.shrink();
                  return DropdownButton<SubtitleTrack>(
                    hint: const Text('Subtitles'),
                    isExpanded: true,
                    items: tracks
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              t.title ??
                                  t.language ??
                                  (t.id == 'no' ? 'Off' : t.id),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (track) {
                      if (track != null) player.setSubtitleTrack(track);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}
