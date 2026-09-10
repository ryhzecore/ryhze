import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/game_library.dart';
import '../core/game_media.dart';
import 'design.dart';

Future<void> gamePermission(BuildContext context, GameLibrary library) async {
  final allow = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Bring your games to Ryhze'),
      content: const SizedBox(
        width: 460,
        child: Text(
          'Allow Ryhze to find installed Steam, Epic and Valorant games, including libraries on other drives? You can add other games yourself.\n\nWhile Ryhze is open, it will check game processes to show Resume and remember when you last played. Game paths and play history stay on this PC. Game titles or store IDs are sent to Steam to load official artwork and footage.\n\nYou can turn this off or clear your history in Installed games at any time.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Allow'),
        ),
      ],
    ),
  );
  if (allow == null) return;
  await library.allow(allow);
  if (allow) await library.scan();
}

Future<void> editLocalGame(
  BuildContext context,
  GameLibrary library, [
  LocalGame? game,
]) async {
  final name = TextEditingController(text: game?.name);
  final path = TextEditingController(text: game?.executable);
  final steam = TextEditingController(
    text: game?.source == 'Epic Games' ? '' : game?.storeId,
  );
  String? error;
  bool saving = false;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text(game == null ? 'Add a game' : 'Edit game'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Game name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: path,
                  decoration: const InputDecoration(
                    labelText: 'Game executable',
                    hintText: r'D:\Games\My Game\Game.exe',
                  ),
                ),
                TextButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          try {
                            final picked = await GameLibrary.channel
                                .invokeMethod<String>('pickExecutable');
                            if (context.mounted && picked?.isNotEmpty == true) {
                              path.text = picked!;
                            }
                          } catch (e) {
                            if (context.mounted) {
                              update(() => error = e.toString());
                            }
                          }
                        },
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Browse this PC'),
                ),
                const Text(
                  'Choose the game executable, not Steam.exe or EpicGamesLauncher.exe. A game installed on another drive works too.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                if (game?.source != 'Epic Games') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: steam,
                    decoration: const InputDecoration(
                      labelText: 'Steam app ID (optional)',
                      helperText:
                          'For exact official artwork and footage. Example: 570.',
                    ),
                  ),
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    update(() {
                      saving = true;
                      error = null;
                    });
                    try {
                      await library.addManual(
                        name.text,
                        path.text,
                        previous: game,
                        steamId: steam.text.trim(),
                      );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        update(() {
                          saving = false;
                          error = e.toString();
                        });
                      }
                    }
                  },
            child: Text(saving ? 'Saving…' : 'Save game'),
          ),
        ],
      ),
    ),
  );
  // Dialog reverse animations can still reference these controllers for a frame.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  name.dispose();
  path.dispose();
  steam.dispose();
}

String lastPlayedText(LocalGame game) {
  final time = game.lastPlayed?.toLocal();
  if (time == null) return 'Not played since adding to Ryhze';
  final ago = DateTime.now().difference(time);
  if (ago.inMinutes < 1) return 'Last played just now';
  if (ago.inHours < 1) return 'Last played ${ago.inMinutes}m ago';
  if (ago.inDays < 1) return 'Last played ${ago.inHours}h ago';
  return 'Last played ${time.day}/${time.month}/${time.year}';
}

class InstalledGamesPage extends StatefulWidget {
  final GameLibrary library;
  final GameMediaStore media;
  final ValueChanged<bool>? onDetailsChanged;
  const InstalledGamesPage({
    super.key,
    required this.library,
    required this.media,
    this.onDetailsChanged,
  });
  @override
  State<InstalledGamesPage> createState() => _InstalledGamesPageState();
}

class _InstalledGamesPageState extends State<InstalledGamesPage> {
  String query = '';
  GameLibrary get library => widget.library;
  Future<void> addLibrary() async {
    final input = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a Steam library folder'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: input,
            decoration: const InputDecoration(
              labelText: 'Folder containing steamapps',
              hintText: r'D:\SteamLibrary',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('Scan folder'),
          ),
        ],
      ),
    );
    if (path?.isNotEmpty == true) await library.scan(extraSteamRoot: path);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
  }

  Future<void> settings() async {
    await showDialog<void>(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: library,
        builder: (context, _) => AlertDialog(
          title: const Text('Game library preferences'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Discovery and activity tracking'),
                  subtitle: const Text(
                    'Only while Ryhze is open. Stored on this PC.',
                  ),
                  value: library.permission == true,
                  onChanged: (value) =>
                      attempt(context, () => library.allow(value)),
                ),
                TextButton(
                  onPressed: () => attempt(context, library.clearHistory),
                  child: const Text('Clear last-played history'),
                ),
                const Text(
                  'Removing a game from Ryhze does not uninstall it. Games you remove stay hidden on future scans.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                TextButton(
                  onPressed: () => attempt(context, () async {
                    await library.prefs.remove('game-library-hidden');
                    if (context.mounted) Navigator.pop(context);
                    await library.scan();
                  }),
                  child: const Text('Restore removed games on next scan'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: library,
    builder: (context, _) {
      final games = library.sorted
          .where(
            (game) => '${game.name} ${game.source}'.toLowerCase().contains(
              query.toLowerCase(),
            ),
          )
          .toList();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Your PC. Your worlds.'),
            const SizedBox(height: 12),
            Text('Installed games.', style: heading(38)),
            const SizedBox(height: 16),
            const Text(
              'Your games, together. Start here, return to your game, and pick up where you left off.',
            ),
            const SizedBox(height: 24),
            if (library.permission != true)
              Glass(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Game discovery is off. Allow access to build your library and remember when you play.',
                    ),
                    const SizedBox(height: 20),
                    Pill(
                      'Set up my games',
                      primary: true,
                      onPressed: () => attempt(
                        context,
                        () => gamePermission(context, library),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Pill('Preferences', icon: Icons.tune, onPressed: settings),
                  ],
                ),
              )
            else ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  Pill(
                    'Add a game',
                    primary: true,
                    icon: Icons.add,
                    onPressed: () => editLocalGame(context, library),
                  ),
                  Pill(
                    library.scanning
                        ? 'Finding games…'
                        : 'Find installed games',
                    icon: Icons.search,
                    onPressed: library.scanning ? null : () => library.scan(),
                  ),
                  Pill(
                    'Add library folder',
                    icon: Icons.folder_open,
                    onPressed: library.scanning ? null : addLibrary,
                  ),
                  Pill('Preferences', icon: Icons.tune, onPressed: settings),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search your games or launcher',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => query = value),
              ),
              if (library.scanning)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator(),
                ),
              if (library.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    library.error!,
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                ),
              const SizedBox(height: 24),
              if (games.isEmpty)
                Glass(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    query.isNotEmpty
                        ? 'No games match your search.'
                        : 'No games found yet. Scan your Steam and Epic libraries, add a Steam library folder on another drive, or choose a game executable.',
                  ),
                ),
              LayoutBuilder(
                builder: (context, size) {
                  final columns = size.maxWidth >= 1100
                      ? 3
                      : size.maxWidth >= 620
                      ? 2
                      : 1;
                  final width = (size.maxWidth - (columns - 1) * 24) / columns;
                  return Wrap(
                    spacing: 24,
                    runSpacing: 28,
                    children: [
                      for (final game in games)
                        SizedBox(
                          width: width,
                          child: _GameCard(
                            game: game,
                            library: library,
                            media: widget.media,
                            onDetailsChanged: widget.onDetailsChanged,
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Activity is tracked while Ryhze is open. Store launchers may need to sign in or finish an update before the game starts.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _GameCard extends StatelessWidget {
  final LocalGame game;
  final GameLibrary library;
  final GameMediaStore media;
  final ValueChanged<bool>? onDetailsChanged;
  const _GameCard({
    required this.game,
    required this.library,
    required this.media,
    this.onDetailsChanged,
  });
  @override
  Widget build(BuildContext context) => Glass(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(surfaceRadius),
          onTap: () async {
            onDetailsChanged?.call(true);
            try {
              await showDialog<void>(
                context: context,
                builder: (context) =>
                    LocalGameDetail(game: game, library: library, media: media),
              );
            } finally {
              onDetailsChanged?.call(false);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(surfaceRadius),
                ),
                child: AspectRatio(
                  aspectRatio: 460 / 215,
                  child: FutureBuilder<GameMedia>(
                    future: media.load(game),
                    builder: (context, snapshot) => GameArtwork(
                      snapshot.data?.artwork ?? '',
                      name: game.name,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(game.source),
                    const SizedBox(height: 10),
                    Text(
                      game.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: heading(23),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      library.isRunning(game)
                          ? 'Playing now'
                          : lastPlayedText(game),
                      style: TextStyle(
                        color: library.isRunning(game)
                            ? const Color(0xffa6e8b4)
                            : muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Details & footage →',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: GameControls(game: game, library: library),
        ),
      ],
    ),
  );
}

class GameArtwork extends StatelessWidget {
  final String url, name;
  final BoxFit fit;
  const GameArtwork(
    this.url, {
    super.key,
    required this.name,
    this.fit = BoxFit.cover,
  });
  Widget fallback() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xff292039), Color(0xff101016)]),
    ),
    child: Center(
      child: Icon(
        Icons.sports_esports_outlined,
        size: 56,
        color: Colors.white.withValues(alpha: .35),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => url == 'asset:assets/art/valorant.png'
      ? Image.asset('assets/art/valorant.png', fit: fit)
      : url.isEmpty || !officialGameMedia(url)
      ? fallback()
      : Image.network(
          url,
          fit: fit,
          semanticLabel: '$name official artwork',
          errorBuilder: (_, _, _) => fallback(),
        );
}

class GameControls extends StatelessWidget {
  final LocalGame game;
  final GameLibrary library;
  const GameControls({super.key, required this.game, required this.library});
  Future<void> stop(BuildContext context) async {
    final force = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Stop ${game.name}?'),
        content: const Text(
          'Close game asks it to exit normally. Force stop ends the detected game processes immediately and can lose unsaved progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Force stop'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Close game'),
          ),
        ],
      ),
    );
    if (force != null && context.mounted) {
      await attempt(
        context,
        () => library.control(game, force ? 'forceStop' : 'stop'),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: library,
    builder: (context, _) {
      final playing = library.isRunning(game),
          starting = library.launching.containsKey(game.id);
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          Pill(
            playing
                ? 'Resume'
                : starting
                ? 'Starting…'
                : 'Start game',
            primary: true,
            icon: Icons.play_arrow,
            onPressed:
                library.permission != true ||
                    library.busy.contains(game.id) ||
                    (starting && !playing)
                ? null
                : () => attempt(
                    context,
                    () => playing
                        ? library.control(game, 'resume')
                        : library.launchGame(game),
                  ),
          ),
          if (playing)
            Pill(
              'Stop',
              icon: Icons.stop,
              onPressed: library.permission == true
                  ? () => stop(context)
                  : null,
            ),
        ],
      );
    },
  );
}

class LocalGameDetail extends StatefulWidget {
  final LocalGame game;
  final GameLibrary library;
  final GameMediaStore media;
  const LocalGameDetail({
    super.key,
    required this.game,
    required this.library,
    required this.media,
  });
  @override
  State<LocalGameDetail> createState() => _LocalGameDetailState();
}

class _LocalGameDetailState extends State<LocalGameDetail>
    with WidgetsBindingObserver {
  Player? player;
  VideoController? video;
  StreamSubscription<String>? errors;
  String? selected, playbackError;
  late Future<GameMedia> media = widget.media.load(widget.game);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) player?.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    errors?.cancel();
    player?.dispose();
    super.dispose();
  }

  Future<void> play(String url) async {
    if (!officialGameMedia(url)) return;
    player ??= Player();
    video ??= VideoController(player!);
    errors ??= player!.stream.error.listen((error) {
      if (mounted) {
        setState(
          () => playbackError =
              'This trailer could not play. Try again or open the official store.',
        );
      }
    });
    setState(() {
      selected = url;
      playbackError = null;
    });
    try {
      await player!.open(Media(url));
    } catch (_) {
      if (mounted) {
        setState(
          () => playbackError = 'This trailer is currently unavailable.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: canvas,
    insetPadding: const EdgeInsets.all(20),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1040),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<GameMedia>(
            future: media,
            builder: (context, snapshot) {
              final data = snapshot.data ?? const GameMedia();
              final game = widget.game;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(game.name, style: heading(32))),
                      IconButton(
                        tooltip: 'Close details',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(
                      width: double.infinity,
                      height: MediaQuery.sizeOf(context).height * .48,
                      child:
                          selected != null &&
                              data.trailers.contains(selected) &&
                              video != null
                          ? Video(controller: video!)
                          : GameArtwork(
                              selected ??
                                  (data.screenshots.isNotEmpty
                                      ? data.screenshots.first
                                      : data.artwork),
                              name: game.name,
                              fit: BoxFit.contain,
                            ),
                    ),
                  ),
                  if (snapshot.connectionState != ConnectionState.done)
                    const LinearProgressIndicator(),
                  if (playbackError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        playbackError!,
                        style: const TextStyle(color: Colors.orangeAccent),
                      ),
                    ),
                  if (data.screenshots.isNotEmpty ||
                      data.trailers.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 90,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (int i = 0; i < data.trailers.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: SizedBox(
                                width: 150,
                                child: InkWell(
                                  onTap: () => play(data.trailers[i]),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      GameArtwork(
                                        i < data.trailerThumbnails.length
                                            ? data.trailerThumbnails[i]
                                            : data.artwork,
                                        name: '${game.name} trailer ${i + 1}',
                                      ),
                                      Container(
                                        color: Colors.black.withValues(
                                          alpha: .35,
                                        ),
                                      ),
                                      Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.play_circle),
                                            Text(
                                              'Trailer ${i + 1}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          for (int i = 0; i < data.screenshots.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: SizedBox(
                                width: 150,
                                child: InkWell(
                                  onTap: () {
                                    player?.pause();
                                    setState(() {
                                      selected = data.screenshots[i];
                                      playbackError = null;
                                    });
                                  },
                                  child: GameArtwork(
                                    data.screenshots[i],
                                    name: '${game.name} screenshot ${i + 1}',
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  GameControls(game: game, library: widget.library),
                  const SizedBox(height: 20),
                  if (data.description.isNotEmpty) Text(data.description),
                  if (snapshot.connectionState == ConnectionState.done &&
                      data.artwork.isEmpty)
                    const Text(
                      'An official gallery is not available here yet. View the original store, or add the exact Steam app ID when editing a manually added game.',
                    ),
                  if (data.source.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Artwork and footage: ${data.source}. Media belongs to its respective publishers.',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (data.store.isNotEmpty)
                        Pill(
                          'Official store',
                          icon: Icons.open_in_new,
                          onPressed: () => attempt(context, () async {
                            if (!await launchUrl(
                              Uri.parse(data.store),
                              mode: LaunchMode.externalApplication,
                            )) {
                              throw StateError('The store could not open.');
                            }
                          }),
                        ),
                      Pill(
                        'Refresh media',
                        icon: Icons.refresh,
                        onPressed: () {
                          widget.media.retry(game);
                          setState(() {
                            media = widget.media.load(game);
                          });
                        },
                      ),
                      Pill(
                        'Edit game',
                        icon: Icons.edit_outlined,
                        onPressed: () async {
                          player?.pause();
                          Navigator.pop(context);
                          await editLocalGame(context, widget.library, game);
                        },
                      ),
                      Pill(
                        'Remove from Ryhze',
                        icon: Icons.remove_circle_outline,
                        onPressed: () => attempt(context, () async {
                          await widget.library.remove(game);
                          if (context.mounted) Navigator.pop(context);
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SelectableText(
                    'Installed in: ${game.root}',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
