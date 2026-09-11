import 'dart:async';
import 'package:flutter/services.dart';
import '../core/models.dart';
import '../core/state.dart';
import 'title_card.dart';
import 'artwork_hero.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/game_library.dart';
import '../core/game_media.dart';
import 'design.dart';
import 'admin_games.dart';

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

class GameLibraryTools extends StatefulWidget {
  final GameLibrary library;
  const GameLibraryTools({super.key, required this.library});
  @override
  State<GameLibraryTools> createState() => _GameLibraryToolsState();
}

class _GameLibraryToolsState extends State<GameLibraryTools> {
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
    builder: (context, _) => PopupMenuButton<String>(
      tooltip: 'Manage games',
      icon: const Icon(Icons.tune, size: 20),
      onSelected: (action) => attempt(context, () async {
        switch (action) {
          case 'allow':
            await gamePermission(context, library);
          case 'add':
            await editLocalGame(context, library);
          case 'scan':
            await library.scan();
          case 'folder':
            await addLibrary();
          case 'preferences':
            await settings();
        }
      }),
      itemBuilder: (_) => [
        if (library.permission != true)
          const PopupMenuItem(value: 'allow', child: Text('Set up my games')),
        if (library.permission == true) ...[
          const PopupMenuItem(value: 'add', child: Text('Add a game')),
          PopupMenuItem(
            value: 'scan',
            enabled: !library.scanning,
            child: Text(
              library.scanning ? 'Finding games…' : 'Find installed games',
            ),
          ),
          PopupMenuItem(
            value: 'folder',
            enabled: !library.scanning,
            child: const Text('Add library folder'),
          ),
        ],
        const PopupMenuItem(
          value: 'preferences',
          child: Text('Game library preferences'),
        ),
      ],
    ),
  );
}

class LocalGameCard extends StatelessWidget {
  final LocalGame game;
  final GameLibrary library;
  final GameMediaStore media;
  final RyhzeState state;
  final bool previewAllowed;
  final ValueChanged<bool>? onDetailsChanged;
  const LocalGameCard({
    super.key,
    required this.game,
    required this.library,
    required this.media,
    required this.state,
    this.previewAllowed = true,
    this.onDetailsChanged,
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: library,
    builder: (context, _) => FutureBuilder<GameMedia>(
      future: media.load(game),
      builder: (context, snapshot) {
        final playing = library.isRunning(game);
        final title = RyhzeTitle(
          id: 'local-${game.id}',
          title: game.name,
          kind: 'game',
          label: game.source,
          status: playing ? 'Playing now' : 'Installed',
          description: '',
          categories: [lastPlayedText(game)],
        );
        final artwork = GameArtwork(
          snapshot.data?.artwork ?? '',
          name: game.name,
        );
        Future<void> open() async {
          final source = artworkBounds(context, 'card-${title.id}');
          onDetailsChanged?.call(true);
          try {
            await Navigator.of(context).push(
              PageRouteBuilder<void>(
                opaque: false,
                barrierDismissible: true,
                barrierLabel: 'Close game details',
                barrierColor: Colors.black.withValues(alpha: .7),
                transitionDuration: Duration(
                  milliseconds: state.reduced ? 0 : 420,
                ),
                reverseTransitionDuration: Duration(
                  milliseconds: state.reduced ? 0 : 420,
                ),
                pageBuilder: (_, _, _) => LocalGameDetail(
                  game: game,
                  library: library,
                  media: media,
                  state: state,
                  heroTag: 'card-${title.id}',
                  cover: snapshot.data?.artwork ?? '',
                ),
                transitionsBuilder: (_, animation, _, child) =>
                    GameFrameTransition(
                      animation: animation,
                      source: source,
                      reduced: state.reduced || MotionSettings.of(context),
                      child: child,
                    ),
              ),
            );
          } finally {
            onDetailsChanged?.call(false);
          }
        }

        return RyhzeTitleCard(
          title: title,
          state: state,
          artwork: artwork,
          previewAllowed: previewAllowed,
          onOpen: open,
          onSave: open,
          trailingAction: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.user?.launcherAdmin == true)
                Pill(
                  'Edit catalogue game',
                  icon: Icons.edit_outlined,
                  iconOnly: true,
                  quiet: true,
                  height: 44,
                  onPressed: () {
                    final matches = state.titles.where(
                      (t) =>
                          t.isGame &&
                          (gameNameKey(t.title) == gameNameKey(game.name) ||
                              (game.source != 'Epic Games' &&
                                  t.storeId.isNotEmpty &&
                                  t.storeId == game.storeId)),
                    );
                    final entry = matches.isNotEmpty
                        ? matches.first
                        : RyhzeTitle(
                            id: 'game-${game.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}',
                            title: game.name,
                            kind: 'game',
                            label: game.source,
                            status: 'Available',
                            description: '',
                            image: '',
                            storeId: game.source == 'Epic Games'
                                ? ''
                                : game.storeId,
                          );
                    editCatalogueGame(context, state, entry);
                  },
                ),
              Pill(
                playing ? 'Resume ${game.name}' : 'Start ${game.name}',
                iconOnly: true,
                quiet: true,
                icon: playing ? Icons.play_arrow : Icons.play_arrow_outlined,
                height: 44,
                onPressed:
                    library.permission != true ||
                        library.launching.containsKey(game.id) ||
                        library.busy.contains(game.id)
                    ? null
                    : () => attempt(
                        context,
                        () => playing
                            ? library.control(game, 'resume')
                            : library.launchGame(game),
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class GameArtwork extends StatelessWidget {
  final String url, name;
  final BoxFit fit;
  final bool thumbnail;
  const GameArtwork(
    this.url, {
    super.key,
    required this.name,
    this.fit = BoxFit.cover,
    this.thumbnail = false,
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
          cacheWidth: thumbnail
              ? (120 * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
                  120,
                  480,
                )
              : null,
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
  final RyhzeState state;
  final String heroTag, cover;
  const LocalGameDetail({
    super.key,
    required this.game,
    required this.library,
    required this.media,
    required this.state,
    required this.heroTag,
    this.cover = '',
  });
  @override
  State<LocalGameDetail> createState() => _LocalGameDetailState();
}

class _LocalGameDetailState extends State<LocalGameDetail>
    with WidgetsBindingObserver {
  Player? player;
  VideoController? video;
  StreamSubscription<String>? errors;
  final thumbnails = ScrollController();
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
    thumbnails.dispose();
    super.dispose();
  }

  List<String> entries(GameMedia data) => [
    if (data.artwork.isNotEmpty) data.artwork,
    ...data.screenshots,
    ...data.trailers,
  ];
  String current(GameMedia data) =>
      selected ??
      (data.artwork.isNotEmpty
          ? data.artwork
          : entries(data).firstOrNull ?? '');
  Future<void> choose(GameMedia data, String url) async {
    if (!officialGameMedia(url) && url != 'asset:assets/art/valorant.png') {
      return;
    }
    setState(() {
      selected = url;
      playbackError = null;
    });
    final index = entries(data).indexOf(url);
    if (thumbnails.hasClients && index >= 0) {
      final offset = (index * 130.0).clamp(
        0.0,
        thumbnails.position.maxScrollExtent,
      );
      if (widget.state.reduced || MotionSettings.of(context)) {
        thumbnails.jumpTo(offset);
      } else {
        unawaited(
          thumbnails.animateTo(
            offset,
            duration: const Duration(milliseconds: 300),
            curve: ryhzeEase,
          ),
        );
      }
    }
    if (!data.trailers.contains(url)) {
      await player?.pause();
      return;
    }
    player ??= Player();
    video ??= VideoController(player!);
    errors ??= player!.stream.error.listen((_) {
      if (mounted) {
        setState(
          () => playbackError =
              'This trailer could not play. Try again or open the official store.',
        );
      }
    });
    if (mounted) setState(() {});
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

  void move(GameMedia data, int direction) {
    final all = entries(data);
    if (all.length < 2) return;
    final index = all.indexOf(current(data));
    unawaited(
      choose(data, all[((index < 0 ? 0 : index) + direction) % all.length]),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<GameMedia>(
    future: media,
    builder: (context, snapshot) {
      final data = snapshot.data ?? GameMedia(artwork: widget.cover);
      final game = widget.game,
          mobile = MediaQuery.sizeOf(context).width <= 700;
      final reduced = widget.state.reduced || MotionSettings.of(context);
      final all = entries(data), selectedUrl = current(data);
      final index = all.indexOf(selectedUrl);
      final isVideo = data.trailers.contains(selectedUrl) && video != null;
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.pop(context),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              move(data, -1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              move(data, 1),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(mobile ? 12 : 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Glass(
                      radius: panelRadius(mobile),
                      frameVisible: !GameFrameMotion.ownsFrame(context),
                      child: Column(
                        children: [
                          DetailControlsReveal(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: mobile ? 18 : 28,
                                vertical: mobile ? 18 : 22,
                              ),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xde111014),
                                    Color(0x33111014),
                                  ],
                                ),
                                border: Border(
                                  bottom: BorderSide(color: Color(0x18ffffff)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Pill(
                                    'Back',
                                    backStyle: true,
                                    icon: Icons.arrow_back,
                                    iconFirst: true,
                                    height: 44,
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(child: Eyebrow(game.source)),
                                  Pill(
                                    'Close details',
                                    iconOnly: true,
                                    icon: Icons.close,
                                    height: 44,
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: EdgeInsets.all(mobile ? 20 : 36),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children:
                                      <Widget>[
                                            ListenableBuilder(
                                              listenable: widget.library,
                                              builder: (_, _) => Eyebrow(
                                                widget.library.isRunning(game)
                                                    ? 'Playing now'
                                                    : 'Installed',
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              game.name,
                                              style: heading(
                                                mobile ? 38 : 56,
                                              ).copyWith(height: 1.1),
                                            ),
                                            const SizedBox(height: 24),
                                            ArtworkHero(
                                              tag: widget.heroTag,
                                              image: '',
                                              state: widget.state,
                                              artwork: GameArtwork(
                                                widget.cover.isEmpty
                                                    ? data.artwork
                                                    : widget.cover,
                                                name: game.name,
                                              ),
                                              child: ClipRSuperellipse(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      surfaceRadius,
                                                    ),
                                                child: SizedBox(
                                                  height:
                                                      MediaQuery.sizeOf(
                                                        context,
                                                      ).height *
                                                      .48,
                                                  child: ColoredBox(
                                                    color: canvas,
                                                    child: AnimatedSwitcher(
                                                      duration: Duration(
                                                        milliseconds: reduced
                                                            ? 0
                                                            : 300,
                                                      ),
                                                      switchInCurve: ryhzeEase,
                                                      child: isVideo
                                                          ? Video(
                                                              key:
                                                                  const ValueKey(
                                                                    'trailer',
                                                                  ),
                                                              controller:
                                                                  video!,
                                                            )
                                                          : SizedBox.expand(
                                                              key: ValueKey(
                                                                selectedUrl,
                                                              ),
                                                              child: GameArtwork(
                                                                selectedUrl,
                                                                name: game.name,
                                                                fit: BoxFit
                                                                    .contain,
                                                              ),
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (snapshot.connectionState !=
                                                ConnectionState.done)
                                              const LinearProgressIndicator(),
                                            if (all.isNotEmpty) ...[
                                              const SizedBox(height: 14),
                                              Row(
                                                children: [
                                                  Pill(
                                                    'Previous image or trailer',
                                                    iconOnly: true,
                                                    icon: Icons.arrow_back,
                                                    height: 44,
                                                    onPressed: all.length > 1
                                                        ? () => move(data, -1)
                                                        : null,
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Text(
                                                      '${index < 0 ? 1 : index + 1} / ${all.length}',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                        color: muted,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  Pill(
                                                    'Next image or trailer',
                                                    iconOnly: true,
                                                    icon: Icons.arrow_forward,
                                                    height: 44,
                                                    onPressed: all.length > 1
                                                        ? () => move(data, 1)
                                                        : null,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              SizedBox(
                                                height: 76,
                                                child: ListView.separated(
                                                  controller: thumbnails,
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  itemCount: all.length,
                                                  separatorBuilder: (_, _) =>
                                                      const SizedBox(width: 10),
                                                  itemBuilder: (context, i) {
                                                    final trailer = data
                                                        .trailers
                                                        .indexOf(all[i]);
                                                    final image = trailer >= 0
                                                        ? (trailer <
                                                                  data
                                                                      .trailerThumbnails
                                                                      .length
                                                              ? data.trailerThumbnails[trailer]
                                                              : data.artwork)
                                                        : all[i];
                                                    return SizedBox(
                                                      width: 120,
                                                      child: Tooltip(
                                                        message: trailer >= 0
                                                            ? 'Trailer ${trailer + 1}'
                                                            : all[i] ==
                                                                  data.artwork
                                                            ? 'Artwork'
                                                            : 'Screenshot ${data.screenshots.indexOf(all[i]) + 1}',
                                                        child: AnimatedContainer(
                                                          duration: Duration(
                                                            milliseconds:
                                                                reduced
                                                                ? 0
                                                                : 300,
                                                          ),
                                                          padding:
                                                              const EdgeInsets.all(
                                                                2,
                                                              ),
                                                          decoration: ShapeDecoration(
                                                            shape: RoundedSuperellipseBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    16,
                                                                  ),
                                                              side: BorderSide(
                                                                color:
                                                                    all[i] ==
                                                                        selectedUrl
                                                                    ? Colors
                                                                          .white
                                                                    : const Color(
                                                                        0x22ffffff,
                                                                      ),
                                                                width: 2,
                                                              ),
                                                            ),
                                                          ),
                                                          child: ClipRSuperellipse(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  14,
                                                                ),
                                                            child: InkWell(
                                                              onTap: () =>
                                                                  choose(
                                                                    data,
                                                                    all[i],
                                                                  ),
                                                              child: Stack(
                                                                fit: StackFit
                                                                    .expand,
                                                                children: [
                                                                  GameArtwork(
                                                                    image,
                                                                    name: game
                                                                        .name,
                                                                    thumbnail:
                                                                        true,
                                                                  ),
                                                                  if (trailer >=
                                                                      0) ...[
                                                                    Container(
                                                                      color: Colors
                                                                          .black
                                                                          .withValues(
                                                                            alpha:
                                                                                .35,
                                                                          ),
                                                                    ),
                                                                    Center(
                                                                      child: Column(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        children: [
                                                                          const Icon(
                                                                            Icons.play_circle,
                                                                          ),
                                                                          Text(
                                                                            'Trailer ${trailer + 1}',
                                                                            style: const TextStyle(
                                                                              fontSize: 11,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                            if (playbackError != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 12,
                                                ),
                                                child: Text(
                                                  playbackError!,
                                                  style: const TextStyle(
                                                    color: Colors.orangeAccent,
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(height: 24),
                                            GameControls(
                                              game: game,
                                              library: widget.library,
                                            ),
                                            const SizedBox(height: 20),
                                            ListenableBuilder(
                                              listenable: widget.library,
                                              builder: (_, _) => Text(
                                                lastPlayedText(game),
                                                style: const TextStyle(
                                                  color: muted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            if (data.description.isNotEmpty)
                                              Text(data.description),
                                            if (snapshot.connectionState ==
                                                    ConnectionState.done &&
                                                all.isEmpty)
                                              const Text(
                                                'An official gallery is not available here yet. View the original store, or add the exact Steam app ID for a manually added game.',
                                              ),
                                            if (data.source.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 12,
                                                ),
                                                child: Text(
                                                  'Artwork and footage: ${data.source}. Media belongs to its respective publishers.',
                                                  style: const TextStyle(
                                                    color: muted,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(height: 24),
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 12,
                                              children: [
                                                if (data.store.isNotEmpty)
                                                  Pill(
                                                    'Official store',
                                                    icon: Icons.open_in_new,
                                                    onPressed: () => attempt(
                                                      context,
                                                      () async {
                                                        if (!await launchUrl(
                                                          Uri.parse(data.store),
                                                          mode: LaunchMode
                                                              .externalApplication,
                                                        )) {
                                                          throw StateError(
                                                            'The store could not open.',
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                Pill(
                                                  'Refresh media',
                                                  icon: Icons.refresh,
                                                  onPressed: () {
                                                    widget.media.retry(game);
                                                    player?.pause();
                                                    setState(() {
                                                      selected = null;
                                                      media = widget.media.load(
                                                        game,
                                                      );
                                                    });
                                                  },
                                                ),
                                                Pill(
                                                  'Edit game',
                                                  icon: Icons.edit_outlined,
                                                  onPressed: () async {
                                                    await player?.pause();
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    await editLocalGame(
                                                      context,
                                                      widget.library,
                                                      game,
                                                    );
                                                    if (context.mounted) {
                                                      Navigator.pop(context);
                                                    }
                                                  },
                                                ),
                                                Pill(
                                                  'Remove from Ryhze',
                                                  icon: Icons
                                                      .remove_circle_outline,
                                                  onPressed: () => attempt(
                                                    context,
                                                    () async {
                                                      await widget.library
                                                          .remove(game);
                                                      if (context.mounted) {
                                                        Navigator.pop(context);
                                                      }
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 18),
                                            SelectableText(
                                              'Installed in: ${game.root}',
                                              style: const TextStyle(
                                                color: muted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ]
                                          .map(
                                            (item) => item is ArtworkHero
                                                ? item
                                                : DetailControlsReveal(
                                                    child: item,
                                                  ),
                                          )
                                          .toList(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
