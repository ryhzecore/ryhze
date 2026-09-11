import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import '../core/models.dart';
import '../core/state.dart';
import '../core/updates.dart';
import 'updates.dart';
import 'design.dart';
import 'details.dart';
import 'pages.dart';
import 'title_card.dart';
import 'studio.dart';
import 'artwork_hero.dart';
import 'home.dart';
import '../core/game_library.dart';
import '../core/game_media.dart';
import 'game_library.dart';
import 'expanding_surface.dart';
import 'admin_games.dart';
import 'engine.dart';

class RyhzeShell extends StatefulWidget {
  final RyhzeState state;
  final AppUpdates? updates;
  final GameLibrary? gameLibrary;
  const RyhzeShell({
    super.key,
    required this.state,
    this.updates,
    this.gameLibrary,
  });
  @override
  State<RyhzeShell> createState() => _RyhzeShellState();
}

class _RyhzeShellState extends State<RyhzeShell> with WidgetsBindingObserver {
  String page = 'games';
  String gameCategory = 'All games';
  GameMediaStore? gameMedia;
  final searchSource = GlobalKey(), menuSource = GlobalKey();
  String? expandedSource;
  final scroll = ScrollController();
  Player? ambient;
  bool active = true, detailOpen = false, overlayOpen = false;
  String? ambientAccount;
  RyhzeState get state => widget.state;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state.addListener(changed);
    final library = widget.gameLibrary;
    if (library != null) {
      gameMedia = GameMediaStore(state.prefs);
      library.start();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted && library.permission == null) {
          await attempt(context, () => gamePermission(context, library));
        }
      });
    }
  }

  void changed() {
    if (page == 'engine' && state.user?.launcherAdmin != true) {
      page = 'games';
    }
    if (state.notice != null) {
      final message = state.notice!;
      state.notice = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) toast(context, message);
      });
    }
    unawaited(syncAudio());
  }

  Future<void> syncAudio() async {
    if (!state.sound || state.user == null || !active || detailOpen) {
      await ambient?.pause();
      return;
    }
    try {
      if (ambient == null || ambientAccount != state.scope) {
        await ambient?.dispose();
        ambient = Player();
        ambientAccount = state.scope;
        await ambient!.setVolume(14);
        await ambient!.setPlaylistMode(PlaylistMode.single);
        await ambient!.open(
          Media(
            state.api.resource('/private-art/audio/menu-loop.mp3').toString(),
            httpHeaders: state.api.authHeaders,
          ),
        );
      } else {
        await ambient!.play();
      }
    } catch (_) {
      /* An unavailable ambient track must never prevent browsing. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    active = value == AppLifecycleState.resumed;
    if (active) widget.updates?.resume();
    unawaited(syncAudio());
  }

  @override
  void dispose() {
    state.removeListener(changed);
    WidgetsBinding.instance.removeObserver(this);
    scroll.dispose();
    ambient?.dispose();
    widget.gameLibrary?.dispose();
    gameMedia?.dispose();
    super.dispose();
  }

  void navigate(String target) {
    if (target == 'engine' && state.user?.launcherAdmin != true) return;
    setState(() => page = target);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void engineDetailsChanged(bool value) {
    if (!mounted) return;
    setState(() => detailOpen = value);
    unawaited(syncAudio());
  }

  Future<void> open(RyhzeTitle title, String tag) async {
    final source = artworkBounds(context, tag);
    setState(() => detailOpen = true);
    await syncAudio();
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierLabel: 'Close details',
        barrierColor: Colors.black.withValues(alpha: .7),
        transitionDuration: Duration(
          milliseconds: state.reduced
              ? 0
              : title.isGame
              ? 420
              : 700,
        ),
        reverseTransitionDuration: Duration(
          milliseconds: state.reduced
              ? 0
              : title.isGame
              ? 420
              : 700,
        ),
        pageBuilder: (_, animation, secondary) => DetailPage(
          title: title,
          state: state,
          heroTag: tag,
          onSignIn: () => navigate('login'),
        ),
        transitionsBuilder: (_, animation, secondary, child) => title.isGame
            ? GameFrameTransition(
                animation: animation,
                source: source,
                reduced: state.reduced || MotionSettings.of(context),
                child: child,
              )
            : FadeTransition(
                opacity: CurvedAnimation(parent: animation, curve: ryhzeEase),
                child: child,
              ),
      ),
    );
    detailOpen = false;
    await syncAudio();
    if (mounted) setState(() {});
  }

  void save(RyhzeTitle title) {
    if (state.user == null) {
      navigate('login');
      return;
    }
    attempt(context, () => state.toggleSaved(title));
  }

  Future<void> search() async {
    if (overlayOpen) return;
    setState(() {
      overlayOpen = true;
      expandedSource = 'search';
    });
    final result = await expandingSurface<RyhzeTitle>(
      context: context,
      source: searchSource,
      icon: Icons.search,
      width: 620,
      height: (114 + state.titles.length * 72.0).clamp(220, 480),
      reduced: state.reduced,
      builder: (_) => SearchPanel(state: state, embedded: true),
    );
    if (!mounted) return;
    setState(() {
      overlayOpen = false;
      expandedSource = null;
    });
    if (result != null) await open(result, 'search-${result.id}');
  }

  Future<void> showUpdates() async {
    final updates = widget.updates;
    if (updates == null) return;
    setState(() => overlayOpen = true);
    if (!updates.available) unawaited(updates.check());
    await showDialog<void>(
      context: context,
      builder: (_) => UpdatePanel(updates: updates),
    );
    if (mounted) setState(() => overlayOpen = false);
  }

  Future<void> menu() async {
    if (overlayOpen) return;
    setState(() {
      overlayOpen = true;
      expandedSource = 'menu';
    });
    await expandingSurface<void>(
      context: context,
      source: menuSource,
      icon: Icons.menu,
      width: 320,
      height:
          (state.user == null ? 520.0 : 640.0) +
          (state.user?.role == 'admin' ? 56 : 0) +
          (widget.updates?.supported == true ? 56 : 0),
      rightAligned: true,
      reduced: state.reduced,
      builder: (dialogContext) => ListenableBuilder(
        listenable: state,
        builder: (_, _) => SizedBox(
          child: SizedBox(
            width: 300,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(
                      state.user == null
                          ? 'Your Ryhze'
                          : 'Welcome, ${state.user!.username}',
                    ),
                    const SizedBox(height: 12),
                    for (final item in [
                      if (state.user == null)
                        ('Sign in', 'login')
                      else
                        ('My List', 'saved'),
                      ('Ryhze home', 'home'),
                      ('Continue watching', 'history'),
                      ('Our story', 'about'),
                      ('Get in touch', 'contact'),
                      ('Privacy', 'privacy'),
                      if (state.user?.role == 'admin')
                        ('Manage members', 'admin'),
                    ])
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.$1,
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: const Icon(Icons.arrow_forward, size: 18),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          navigate(item.$2);
                        },
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Reduced motion',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: state.reduced,
                      onChanged: (v) => attempt(
                        context,
                        () => state.preference('reduced-motion', v),
                      ),
                    ),
                    if (state.user != null)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Ambient sound',
                          style: TextStyle(fontSize: 13),
                        ),
                        value: state.sound,
                        onChanged: (v) => attempt(
                          context,
                          () => state.preference('ambient-sound', v),
                        ),
                      ),
                    if (state.user != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Sign out',
                          style: TextStyle(fontSize: 13),
                        ),
                        trailing: const Icon(Icons.logout, size: 18),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          attempt(context, () async {
                            await state.logout();
                            PaintingBinding.instance.imageCache.clear();
                            PaintingBinding.instance.imageCache
                                .clearLiveImages();
                            navigate('games');
                          });
                        },
                      ),
                    if (widget.updates?.supported == true)
                      ListenableBuilder(
                        listenable: widget.updates!,
                        builder: (_, _) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            widget.updates!.available
                                ? Icons.system_update_alt
                                : Icons.refresh,
                            size: 20,
                          ),
                          title: Text(
                            widget.updates!.available
                                ? 'Update available'
                                : 'App updates',
                            style: const TextStyle(fontSize: 13),
                          ),
                          onTap: () {
                            Navigator.pop(dialogContext);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) showUpdates();
                            });
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ryhze $appVersion',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) {
      setState(() {
        overlayOpen = false;
        expandedSource = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([state, widget.gameLibrary]),
    builder: (_, _) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): search,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): search,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, size) {
                final width = size.maxWidth,
                    mobile = width <= 700,
                    gutter = width <= 350
                        ? 16.0
                        : mobile
                        ? 22.0
                        : (width * .045).clamp(20.0, 88.0);
                if (state.loading &&
                    state.titles.isEmpty &&
                    !['login', 'activate'].contains(page)) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/brand/wordmark.png', width: 160),
                        const SizedBox(height: 28),
                        const Text(
                          'Opening a world of possibilities.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 24),
                        const SizedBox(
                          width: 100,
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    Container(
                      height: width <= 480
                          ? 140
                          : mobile
                          ? 88
                          : 104,
                      padding: EdgeInsets.symmetric(
                        horizontal: width <= 350 ? 14 : gutter,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xf509090c), Color(0x9909090c)],
                        ),
                        border: Border(
                          bottom: BorderSide(color: Color(0x0cffffff)),
                        ),
                      ),
                      child: Flex(
                        direction: width <= 480
                            ? Axis.vertical
                            : Axis.horizontal,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Semantics(
                                label: 'Ryhze home',
                                button: true,
                                child: InkWell(
                                  onTap: () => navigate('home'),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    mobile
                                        ? 'assets/brand/symbol.png'
                                        : 'assets/brand/wordmark.png',
                                    width: mobile
                                        ? (width <= 350 ? 34 : 40)
                                        : 124,
                                    height: mobile
                                        ? (width <= 350 ? 34 : 40)
                                        : null,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: width <= 350
                                    ? 6
                                    : width <= 480
                                    ? 10
                                    : mobile
                                    ? 15
                                    : width <= 1000
                                    ? 20
                                    : 30,
                              ),
                              BrowseTabs(
                                page: page,
                                onChanged: navigate,
                                engineAvailable:
                                    state.user?.launcherAdmin == true,
                              ),
                            ],
                          ),
                          if (width > 480)
                            const Spacer()
                          else
                            const SizedBox(height: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (width > 1000) ...[
                                TextButton(
                                  onPressed: () => navigate('about'),
                                  child: const Text(
                                    'Our story',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 20),
                              ],
                              Opacity(
                                opacity: expandedSource == 'search' ? 0 : 1,
                                child: Pill(
                                  key: searchSource,
                                  'Search Ryhze',
                                  height: mobile ? 44 : 48,
                                  icon: Icons.search,
                                  iconOnly: true,
                                  onPressed: search,
                                  reduced: state.reduced,
                                ),
                              ),
                              SizedBox(
                                width: width <= 350
                                    ? 4
                                    : mobile
                                    ? 7
                                    : 10,
                              ),
                              Opacity(
                                opacity: expandedSource == 'menu' ? 0 : 1,
                                child: Pill(
                                  key: menuSource,
                                  'Account and settings',
                                  height: mobile ? 44 : 48,
                                  icon: Icons.menu,
                                  iconOnly: true,
                                  onPressed: menu,
                                  reduced: state.reduced,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Pill(
                                'Game library',
                                height: mobile ? 44 : 48,
                                icon: Icons.library_books_outlined,
                                iconOnly: true,
                                onPressed: () => navigate('library'),
                                reduced: state.reduced,
                              ),
                              if (!mobile && state.user == null) ...[
                                const SizedBox(width: 14),
                                Pill(
                                  'Sign in',
                                  icon: Icons.arrow_forward,
                                  onPressed: () => navigate('login'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.updates?.supported == true)
                      UpdateBanner(
                        updates: widget.updates!,
                        onOpen: showUpdates,
                      ),
                    if (state.loading)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, viewport) => SingleChildScrollView(
                          controller: scroll,
                          child: AnimatedSwitcher(
                            duration: Duration(
                              milliseconds: MotionSettings.of(context)
                                  ? 0
                                  : 320,
                            ),
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                for (final child in previous)
                                  IgnorePointer(
                                    child: ExcludeSemantics(
                                      child: HeroMode(
                                        enabled: false,
                                        child: child,
                                      ),
                                    ),
                                  ),
                                ?current,
                              ],
                            ),
                            child: ConstrainedBox(
                              key: ValueKey(page),
                              constraints: BoxConstraints(
                                minHeight: viewport.maxHeight,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if ([
                                    'games',
                                    'films',
                                    'saved',
                                    'history',
                                    'library',
                                  ].contains(page))
                                    library(width, gutter, size.maxHeight)
                                  else if (page == 'login' ||
                                      page == 'activate')
                                    AuthPage(
                                      state: state,
                                      activation: page == 'activate',
                                      onNavigate: navigate,
                                    )
                                  else if (page == 'home')
                                    BrandHome(
                                      navigate: navigate,
                                      onUpdates:
                                          widget.updates?.supported == true
                                          ? showUpdates
                                          : null,
                                    )
                                  else if (page == 'engine')
                                    EngineCataloguePage(
                                      state: state,
                                      horizontalPadding: gutter,
                                      onDetailsChanged: engineDetailsChanged,
                                    )
                                  else if (page == 'admin')
                                    AdminPage(state: state)
                                  else
                                    EditorialPage(
                                      page: page,
                                      navigate: navigate,
                                    ),
                                  footer(gutter),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  Widget library(double width, double gutter, double height) {
    return catalogueLibrary(width, gutter, height);
  }

  Widget catalogueLibrary(double width, double gutter, double height) {
    final downloaded = page == 'library';
    final isGames = page == 'games' || downloaded;
    final categories = {
      'All games',
      'Installed games',
      for (final t in state.titles.where((t) => t.isGame)) ...t.categories,
    }.toList();
    final category = categories.contains(gameCategory)
        ? gameCategory
        : 'All games';
    final local =
        isGames &&
            widget.gameLibrary?.permission == true &&
            (downloaded ||
                category == 'All games' ||
                category == 'Installed games')
        ? widget.gameLibrary!.sorted
        : <LocalGame>[];
    final items = state.titles
        .where(
          (t) => downloaded
              ? false
              : page == 'saved'
              ? state.saved.contains(t.id)
              : page == 'history'
              ? state.history.containsKey(t.id)
              : t.kind == (page == 'games' ? 'game' : 'film'),
        )
        .toList();
    final hero = items.isEmpty ? null : items.first;
    if (isGames) {
      items.removeWhere(
        (title) => local.any(
          (game) =>
              gameNameKey(game.name) == gameNameKey(title.title) ||
              (game.source != 'Epic Games' &&
                  title.storeId.isNotEmpty &&
                  title.storeId == game.storeId),
        ),
      );
    }
    if (isGames && !downloaded && category != 'All games') {
      items.removeWhere(
        (t) =>
            category == 'Installed games' || !t.categories.contains(category),
      );
    }
    final count = items.length + local.length +
        (downloaded && state.user?.launcherAdmin == true ? 1 : 0);
    final personal = page == 'saved' || page == 'history';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!personal && !downloaded) heroSection(hero, width, gutter, height),
        Padding(
          padding: EdgeInsets.fromLTRB(
            gutter,
            width <= 700 ? 22 : 40,
            gutter,
            width <= 700 ? 50 : 80,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(
                          downloaded
                              ? 'Ready when you are'
                              : personal
                              ? 'Keep your favourites close'
                              : 'Find your next world',
                        ),
                        const SizedBox(height: 10),
                        Text(
                          downloaded
                              ? 'Your library.'
                              : page == 'saved'
                              ? 'My List.'
                              : page == 'history'
                              ? 'Continue watching.'
                              : page == 'films'
                              ? 'Films & series.'
                              : 'Made to explore.',
                          style: heading((width * .03).clamp(30, 44)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${count.toString().padLeft(2, '0')} ${count == 1 ? 'title' : 'titles'}',
                    style: const TextStyle(fontSize: 10, color: muted),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              if (downloaded && state.user?.launcherAdmin == true)
                InstalledEngineCard(
                  state: state,
                  onDetailsChanged: engineDetailsChanged,
                ),
              if (isGames && !downloaded && state.user?.launcherAdmin == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Pill(
                      'Add game',
                      icon: Icons.add,
                      onPressed: () => editCatalogueGame(context, state),
                    ),
                  ),
                ),
              if (isGames && widget.gameLibrary != null) ...[
                Row(
                  children: [
                    if (!downloaded)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 250,
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(category),
                              initialValue: category,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                              ),
                              isExpanded: true,
                              items: [
                                for (final category in categories)
                                  DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => gameCategory = value);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    GameLibraryTools(library: widget.gameLibrary!),
                  ],
                ),
                if (widget.gameLibrary!.scanning)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
                if (widget.gameLibrary!.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      widget.gameLibrary!.error!,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
                const SizedBox(height: 28),
              ],
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Glass(
                    padding: const EdgeInsets.all(20),
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${state.error}\nShowing the last available public catalogue.',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Pill('Try again', onPressed: state.refresh),
                      ],
                    ),
                  ),
                ),
              if (personal && state.user == null)
                empty(
                  'Your own corner of Ryhze.',
                  'Sign in to find your saved titles and continue watching.',
                  'Sign in',
                  () => navigate('login'),
                )
              else if (isGames && widget.gameLibrary != null && count == 0)
                empty(
                  downloaded
                      ? 'Your library is ready for games.'
                      : 'No games in this category.',
                  widget.gameLibrary?.permission == true
                      ? 'Use Manage games to find installations or add a game path.'
                      : 'Allow discovery to include games installed on this PC.',
                  widget.gameLibrary?.permission == true
                      ? 'Add a game'
                      : 'Set up my games',
                  () => attempt(
                    context,
                    () => widget.gameLibrary?.permission == true
                        ? editLocalGame(context, widget.gameLibrary!)
                        : gamePermission(context, widget.gameLibrary!),
                  ),
                )
              else if (downloaded && widget.gameLibrary == null)
                const Text(
                  'Installed PC games are available in the Ryhze Windows app. Open Ryhze on your PC to find and launch your games.',
                )
              else if (items.isEmpty && local.isEmpty)
                empty(
                  personal
                      ? 'Make room for your favourites.'
                      : 'Every story starts somewhere.',
                  personal
                      ? 'Explore a title and add it to My List, or start watching a film.'
                      : 'Our films and series are in the making. Get to know the studio behind them.',
                  personal ? 'Explore Ryhze' : 'Our story',
                  () => navigate(personal ? 'games' : 'about'),
                )
              else
                LayoutBuilder(
                  builder: (_, constraints) {
                    final columns = width <= 480
                        ? 1
                        : width <= 1000
                        ? 2
                        : width >= 1900
                        ? 4
                        : 3;
                    final gap = width <= 700 ? 22.0 : 28.0;
                    final cardWidth =
                        (constraints.maxWidth - (columns - 1) * gap) / columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final title in items)
                          SizedBox(width: cardWidth, child: titleCard(title)),
                        for (final game in local)
                          SizedBox(
                            width: cardWidth,
                            child: LocalGameCard(
                              key: ValueKey(game.id),
                              game: game,
                              library: widget.gameLibrary!,
                              media: gameMedia!,
                              state: state,
                              previewAllowed: !detailOpen && !overlayOpen,
                              onDetailsChanged: (open) {
                                if (!mounted) return;
                                setState(() => detailOpen = open);
                                unawaited(syncAudio());
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              if (page == 'history' && items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Pill(
                    'Clear watch history',
                    onPressed: () => attempt(context, state.clearHistory),
                  ),
                ),
            ],
          ),
        ),
        if (!personal)
          StudioBand(gutter: gutter, onAbout: () => navigate('about')),
      ],
    );
  }

  Widget empty(
    String title,
    String copy,
    String action,
    VoidCallback callback,
  ) => Glass(
    padding: const EdgeInsets.all(32),
    child: SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: heading(28)),
          const SizedBox(height: 16),
          Text(copy),
          const SizedBox(height: 24),
          Pill(action, onPressed: callback),
        ],
      ),
    ),
  );
  Widget heroSection(
    RyhzeTitle? title,
    double width,
    double gutter,
    double viewportHeight,
  ) {
    final mobile = width <= 700;
    final heroHeight = mobile
        ? (width <= 480 ? 630.0 : 660.0)
        : (viewportHeight * .73).clamp(580.0, 840.0);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: heroHeight),
      child: Stack(
        children: [
          if (title != null)
            Positioned.fill(
              child: Opacity(
                opacity: mobile ? .78 : .83,
                child: ArtworkHero(
                  image: title.image,
                  state: state,
                  tag: 'hero-${title.id}',
                  child: TitleArt(
                    title.image,
                    state,
                    alignment: mobile
                        ? const Alignment(.2, -.4)
                        : const Alignment(.3, -.12),
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(.7, -.6),
                    radius: 1.2,
                    colors: [Color(0x505500ff), canvas],
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xf509090c),
                    Color(0xc709090c),
                    Color(0x4509090c),
                    Color(0x1009090c),
                  ],
                  stops: [.02, .3, .65, 1],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    canvas,
                    if (mobile) const Color(0xdb09090c),
                    mobile ? const Color(0x3009090c) : Colors.transparent,
                  ],
                  stops: mobile ? [0, .35, .9] : [0, .4],
                ),
              ),
            ),
          ),
          Container(
            constraints: BoxConstraints(minHeight: heroHeight),
            padding: EdgeInsets.fromLTRB(
              gutter,
              mobile ? (width <= 350 ? 80 : 90) : 70,
              gutter,
              mobile ? 130 : 120,
            ),
            child: Align(
              alignment: mobile ? Alignment.bottomLeft : Alignment.centerLeft,
              child: SizedBox(
                width: mobile
                    ? width
                    : width >= 1900
                    ? 720
                    : width <= 1000
                    ? (width - 2 * gutter) * .72
                    : ((width - 2 * gutter) * .63).clamp(0, 650),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(
                      title?.internal == true
                          ? 'Private library'
                          : title?.label ?? 'Ryhze Studio / Ryhze Television',
                    ),
                    SizedBox(height: mobile ? 16 : 20),
                    Text(
                      title?.title ?? 'Stories,\nmade to stay.',
                      style: heading(
                        width <= 350
                            ? 46
                            : width <= 480
                            ? 52
                            : mobile
                            ? (width * .1).clamp(48, 68)
                            : width >= 1900
                            ? 108
                            : (width * .059).clamp(48, 94),
                      ).copyWith(height: 1.01),
                    ),
                    const SizedBox(height: 24),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: width >= 1900
                            ? 540
                            : mobile
                            ? 430
                            : 450,
                      ),
                      child: Text(
                        title?.description ??
                            'A home for the films and series we’re making. Different voices. One unmistakable Ryhze feeling.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: width >= 1900
                              ? 16
                              : mobile
                              ? 13
                              : 14,
                          height: mobile ? 1.85 : 1.9,
                          color: Color(0xffd4d1db),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        Pill(
                          title == null
                              ? 'Meet Ryhze'
                              : title.isGame
                              ? 'Explore the game'
                              : 'Explore the film',
                          primary: true,
                          icon: Icons.arrow_forward,
                          reduced: state.reduced,
                          onPressed: () => title == null
                              ? navigate('about')
                              : open(title, 'hero-${title.id}'),
                        ),
                        if (title != null)
                          Pill(
                            state.saved.contains(title.id)
                                ? 'In My List'
                                : 'My List',
                            icon: state.saved.contains(title.id)
                                ? Icons.check
                                : Icons.add,
                            iconFirst: true,
                            onPressed: () => save(title),
                            reduced: state.reduced,
                          ),
                      ],
                    ),
                    SizedBox(height: mobile ? 22 : 30),
                    Text(
                      '•  ${title?.status ?? 'Our next chapter is taking shape'}${title != null && title.categories.isNotEmpty ? '     /     ${title.categories.first}' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xffb8b3c2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: gutter,
            right: gutter,
            bottom: mobile ? 30 : 35,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title?.imageNote ?? 'Entertainment has no limits.',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xff96909f),
                    ),
                  ),
                ),
                const Text(
                  '01    /    01',
                  style: TextStyle(fontSize: 10, letterSpacing: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget titleCard(RyhzeTitle title) => RyhzeTitleCard(
    title: title,
    state: state,
    previewAllowed: !detailOpen && !overlayOpen,
    onOpen: () => open(title, 'card-${title.id}'),
    onSave: () => save(title),
    trailingAction: title.isGame && state.user?.launcherAdmin == true
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Pill(
                'Edit ${title.title}',
                iconOnly: true,
                quiet: true,
                icon: Icons.edit_outlined,
                onPressed: () => editCatalogueGame(context, state, title),
              ),
              Pill(
                'Add to My List',
                iconOnly: true,
                quiet: true,
                icon: state.saved.contains(title.id) ? Icons.check : Icons.add,
                onPressed: () => save(title),
              ),
            ],
          )
        : null,
    progress: page == 'history'
        ? ((state.history[title.id]?['position'] ?? 0) /
                  ((state.history[title.id]?['duration'] ?? 1) as num).clamp(
                    1,
                    double.infinity,
                  ))
              .clamp(0.0, 1.0)
        : null,
  );
  Widget footer(double gutter) =>
      RyhzeFooter(gutter: gutter, navigate: navigate);
}

class SearchPanel extends StatefulWidget {
  final RyhzeState state;
  final bool embedded;
  const SearchPanel({super.key, required this.state, this.embedded = false});
  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  String query = '';
  final inputFocus = FocusNode();
  Animation<double>? opening;
  void focusAfterExpansion(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      inputFocus.requestFocus();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = ModalRoute.of(context)?.animation;
    if (opening == next) return;
    opening?.removeStatusListener(focusAfterExpansion);
    opening = next;
    opening?.addStatusListener(focusAfterExpansion);
    if (opening == null || opening!.isCompleted) inputFocus.requestFocus();
  }

  @override
  void dispose() {
    opening?.removeStatusListener(focusAfterExpansion);
    inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.state.titles.where((t) => t.matches(query)).toList();
    final content = Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.search),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  focusNode: inputFocus,
                  decoration: const InputDecoration(
                    hintText: 'Find your next world',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              Pill(
                'Close search',
                iconOnly: true,
                onPressed: () => Navigator.pop(context),
                icon: Icons.close,
              ),
            ],
          ),
          const Divider(),
          Flexible(
            child: results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('No matches for “$query”. Try another title.'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: results.length,
                    itemBuilder: (_, i) {
                      final t = results[i];
                      return ListTile(
                        title: Text(t.title),
                        subtitle: Text(
                          '${t.isGame ? 'Game' : 'Film'} · ${t.status}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: const Icon(Icons.arrow_forward, size: 18),
                        onTap: () => Navigator.pop(context, t),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
    if (widget.embedded) return content;
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(20, 78, 20, 20),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.sizeOf(context).height * .65,
        ),
        child: Glass(radius: popoverRadius, child: content),
      ),
    );
  }
}
