import 'artwork_hero.dart';
import 'agreement_dialog.dart';
import 'option_menu.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import '../core/models.dart';
import '../core/state.dart';
import '../core/updates.dart';
import 'updates.dart';
import 'design.dart';
import 'desktop_window.dart';
import 'details.dart';
import 'pages.dart';
import 'title_card.dart';
import '../core/game_library.dart';
import '../core/game_media.dart';
import 'game_library.dart';
import 'expanding_surface.dart';
import 'admin_games.dart';
import 'engine.dart';
import 'engine_support.dart';
import 'dart:io' show Platform;
import 'personal_library.dart';
import 'big_picture.dart';
import 'game_shelf.dart';
import 'launch_home.dart';
import 'portal.dart';
import 'report_bug.dart';
import 'menu_navigation_tile.dart';

class RyhzeShell extends StatefulWidget {
  final RyhzeState state;
  final AppUpdates? updates;
  final GameLibrary? gameLibrary;
  final bool startupBlocked;
  final bool initialBigPicture;
  final bool initialSignIn;
  const RyhzeShell({
    super.key,
    required this.state,
    this.updates,
    this.gameLibrary,
    this.startupBlocked = false,
    this.initialBigPicture = false,
    this.initialSignIn = false,
  });
  @override
  State<RyhzeShell> createState() => _RyhzeShellState();
}

class _RyhzeShellState extends State<RyhzeShell> with WidgetsBindingObserver {
  String page = 'games';
  bool startupAuthResolved = false;
  bool automaticWebsiteSignIn = false;
  final navigationHistory = <String>[];
  String gameCategory = 'All games';
  GameMediaStore? gameMedia;
  final searchSource = GlobalKey(), menuSource = GlobalKey();
  String? expandedSource;
  final scroll = ScrollController();
  Player? ambient;
  bool active = true, detailOpen = false, overlayOpen = false;
  Future<void> audioSync = Future.value();
  bool permissionRequested = false;
  final engineSupportChecked = <String>{};
  bool checkingEngineSupport = false;
  DateTime? engineSupportAttempt;
  Future<void> checkEngineSupport() async {
    if (!mounted ||
        !Platform.isWindows ||
        widget.startupBlocked ||
        !state.engineAccess ||
        detailOpen ||
        overlayOpen ||
        checkingEngineSupport ||
        engineSupportChecked.contains(state.scope)) {
      return;
    }
    if (engineSupportAttempt != null &&
        DateTime.now().difference(engineSupportAttempt!) <
            const Duration(seconds: 30)) {
      return;
    }
    final stored = state.prefs.getString('race-managed-installations');
    if (stored == null || stored == '{}') return;
    checkingEngineSupport = true;
    engineSupportAttempt = DateTime.now();
    final account = state.scope;
    try {
      final catalogue = await state.api.request('/api/engine/releases');
      if (!mounted || !state.engineAccess || state.scope != account) return;
      engineSupportChecked.add(account);
      final builds = unsupportedManagedBuilds(
        stored,
        catalogue['unsupported'] ?? [],
      );
      if (builds.isNotEmpty) {
        await offerUnsupportedEngineRemoval(context, state, builds);
      }
    } catch (_) {
      /* Retry on reconnect/resume; offline never means unsupported. */
    } finally {
      checkingEngineSupport = false;
    }
  }

  late bool bigPicture = widget.initialBigPicture;
  RyhzeState get state => widget.state;
  bool agreementShowing = false;

  /// The tester agreement the website is serving, shown once per account per
  /// device after sign-in. Declining signs the person out; nothing else in
  /// the app is reachable behind it.
  Future<void> maybeShowAgreement() async {
    final agreement = state.pendingAgreement;
    if (!mounted || agreementShowing || agreement == null) return;
    agreementShowing = true;
    try {
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AgreementDialog(
          title: agreement.title,
          intro:
              'Read the agreement to the end, then confirm to continue to Ryhze.',
          text: agreement.text,
          checkboxLabel: 'I have read and agree to the ${agreement.title}.',
          confirmLabel: 'Agree and continue',
          cancelLabel: 'Sign out',
          authorization: state,
          canConfirm: () => state.user != null,
          blockedMessage: 'Your session ended. Sign in again to continue.',
          scrollKey: const ValueKey('tester-agreement-scroll'),
        ),
      );
      if (!mounted) return;
      if (accepted == true) {
        await state.acceptAgreement();
      } else {
        await state.declineAgreement();
      }
    } finally {
      agreementShowing = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state.addListener(changed);
    resolveStartupAuth();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(syncAudio());
        unawaited(checkEngineSupport());
      }
    });
    final library = widget.gameLibrary;
    if (library != null) {
      gameMedia = GameMediaStore(state.prefs);
      library.start();
      requestGamePermission();
    }
  }

  void requestGamePermission() {
    final library = widget.gameLibrary;
    if (widget.startupBlocked || permissionRequested || library == null) return;
    permissionRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && library.permission == null) {
        await attempt(context, () => gamePermission(context, library));
      }
    });
  }

  @override
  void didUpdateWidget(covariant RyhzeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startupBlocked && !widget.startupBlocked) {
      requestGamePermission();
      unawaited(checkEngineSupport());
      unawaited(syncAudio());
    }
  }

  void changed() {
    resolveStartupAuth();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(maybeShowAgreement());
        unawaited(checkEngineSupport());
      }
    });
    if ((page == 'engine' && !state.engineAccess) ||
        (page == 'admin' && !state.adminAccess) ||
        (page == 'portal' && !state.portalAccess)) {
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

  void resolveStartupAuth() {
    if (startupAuthResolved || state.loading) return;
    startupAuthResolved = true;
    if (widget.initialSignIn &&
        state.api.websiteSignInSupported &&
        state.user == null) {
      page = 'login';
      automaticWebsiteSignIn =
          state.api.websiteSignInSupported &&
          !(state.prefs.getBool('website-sign-in-shown') ?? false);
    }
  }

  Future<void> syncAudio() => audioSync = audioSync.then((_) => updateAudio());

  Future<void> updateAudio() async {
    if (!mounted) return;
    try {
      if (widget.startupBlocked || !state.sound || !active || detailOpen) {
        await ambient?.pause();
        return;
      }
      if (ambient == null) {
        ambient = Player();
        await ambient!.setVolume(14);
        await ambient!.setPlaylistMode(PlaylistMode.single);
        await ambient!.open(
          Media('asset:///assets/audio/menu-loop.mp3'),
          play: false,
        );
      }
      if (mounted &&
          !widget.startupBlocked &&
          state.sound &&
          active &&
          !detailOpen) {
        await ambient!.play();
      }
    } catch (_) {
      /* An unavailable ambient track must never prevent browsing. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    active = value == AppLifecycleState.resumed;
    if (active) {
      widget.updates?.resume();
      unawaited(checkEngineSupport());
    }
    unawaited(syncAudio());
  }

  @override
  void dispose() {
    state.removeListener(changed);
    WidgetsBinding.instance.removeObserver(this);
    scroll.dispose();
    unawaited(
      audioSync.then<void>((_) async {
        await ambient?.dispose();
      }),
    );
    widget.gameLibrary?.dispose();
    gameMedia?.dispose();
    super.dispose();
  }

  void navigate(String target) {
    if (['home', 'about', 'contact'].contains(target)) target = 'games';
    if (target == 'engine' && !state.engineAccess) return;
    if (bigPicture && target != page) navigationHistory.add(page);
    setState(() => page = target);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  bool backPage() {
    while (navigationHistory.isNotEmpty) {
      final target = navigationHistory.removeLast();
      if ((target == 'engine' && !state.engineAccess) ||
          (target == 'admin' && !state.adminAccess) ||
          (target == 'portal' && !state.portalAccess) ||
          (target == 'login' && state.user != null) ||
          target == page) {
        continue;
      }
      setState(() => page = target);
      if (scroll.hasClients) scroll.jumpTo(0);
      return true;
    }
    return false;
  }

  void setBigPicture(bool enabled) {
    DesktopWindowScope.of(context)?.setFullscreen(enabled);
    navigationHistory.clear();
    setState(() => bigPicture = enabled);
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
          milliseconds: state.reduced ? 0 : artworkTransitionMilliseconds,
        ),
        reverseTransitionDuration: Duration(
          milliseconds: state.reduced ? 0 : artworkTransitionMilliseconds,
        ),
        pageBuilder: (_, animation, secondary) => DetailPage(
          title: title,
          state: state,
          heroTag: tag,
          onSignIn: () => navigate('login'),
        ),
        transitionsBuilder: (_, animation, secondary, child) =>
            GameFrameTransition(
              animation: animation,
              source: source,
              reduced: state.reduced || MotionSettings.of(context),
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
      height: (114 + state.visibleTitles.length * 72.0).clamp(220, 480),
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
    VoidCallback? afterMenu;
    final compactHeader = MediaQuery.sizeOf(context).width <= 480;
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
          (state.user == null ? 464.0 : 528.0) +
          (bigPicture && state.user != null ? -56 : 0) +
          (state.user?.role == 'admin' ? 56 : 0) +
          (state.adminAccess ? 56 : 0) +
          (state.publishingAccess ? 56 : 0) +
          (state.portalAccess ? 56 : 0) +
          (compactHeader ? 56 : 0) +
          (compactHeader && state.catalogueUpdateAvailable ? 56 : 0) +
          (compactHeader && widget.gameLibrary?.isLinux == true ? 56 : 0) +
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
                    if (state.user?.role == 'admin')
                      SwitchListTile(
                        key: const ValueKey('admin-access-toggle'),
                        autofocus: bigPicture,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Admin access',
                          style: TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          state.adminAccess
                              ? 'Admin controls shown'
                              : 'Normal user view',
                        ),
                        value: state.adminAccess,
                        onChanged: (value) =>
                            attempt(context, () => state.setAdminAccess(value)),
                      ),
                    for (final item in [
                      if (compactHeader) ('Search Ryhze', 'search'),
                      if (compactHeader && state.catalogueUpdateAvailable)
                        ('Apply catalogue update', 'catalogue-update'),
                      if (compactHeader && widget.gameLibrary?.isLinux == true)
                        (
                          bigPicture ? 'Exit Big Picture' : 'Big Picture',
                          'big-picture',
                        ),
                      if (state.user == null) ('Sign in', 'login'),
                      ('Games Library', 'library'),
                      ('Films Library', 'film-library'),
                      if (state.publishingAccess) ('Publish', 'publishing'),
                      if (state.portalAccess) ('AI', 'portal'),
                      ('Report Bug', 'report-bug'),
                      ('Privacy', 'privacy'),
                      if (state.adminAccess) ('Manage members', 'admin'),
                    ])
                      MenuNavigationTile(
                        label: item.$1,
                        controller: bigPicture,
                        reduced: state.reduced,
                        autofocus:
                            bigPicture &&
                            state.user?.role != 'admin' &&
                            item.$2 ==
                                (state.user == null ? 'login' : 'library'),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          if (item.$2 == 'search') {
                            afterMenu = search;
                          } else if (item.$2 == 'catalogue-update') {
                            afterMenu = state.applyCatalogueUpdate;
                          } else if (item.$2 == 'big-picture') {
                            afterMenu = () => setBigPicture(!bigPicture);
                          } else if (item.$2 == 'report-bug') {
                            showDialog<void>(
                              context: context,
                              builder: (_) => const ReportBugPanel(),
                            );
                          } else if (item.$2 == 'publishing') {
                            if (state.publishingAccess) {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      GamePublishingPage(state: state),
                                ),
                              );
                            }
                          } else if (item.$2 == 'portal') {
                            attempt(context, () async {
                              setState(() => detailOpen = true);
                              await syncAudio();
                              if (!mounted) return;
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PortalPage(state: state),
                                ),
                              );
                              if (!mounted) return;
                              setState(() => detailOpen = false);
                              await syncAudio();
                            });
                          } else {
                            navigate(item.$2);
                          }
                        },
                      ),
                    if (widget.gameLibrary?.isLinux == true)
                      const LaunchHomeSetting(),
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
                    if (state.user != null && !bigPicture)
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
      afterMenu?.call();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([state, widget.gameLibrary]),
    builder: (_, _) => bigPicture
        ? BigPicture(
            onBack: backPage,
            onExit: () => setBigPicture(false),
            child: regularShell(context),
          )
        : regularShell(context),
  );

  Widget regularShell(BuildContext context) => CallbackShortcuts(
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
                  gutter = bigPicture
                      ? 28.0
                      : width <= 350
                      ? 16.0
                      : mobile
                      ? 22.0
                      : (width * .045).clamp(20.0, 88.0);
              if (state.loading &&
                  state.visibleTitles.isEmpty &&
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
                      const SizedBox(width: 360, child: StatusProgress()),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  IOSGlassChrome(
                    radius: 0,
                    child: Container(
                      height: bigPicture
                          ? 88
                          : mobile
                          ? 88
                          : 104,
                      padding: EdgeInsets.symmetric(
                        horizontal: width <= 350 ? 14 : gutter,
                      ),
                      decoration: BoxDecoration(
                        color: usesIOSLiquidGlass ? Colors.transparent : canvas,
                        border: const Border(
                          bottom: BorderSide(color: Color(0x0cffffff)),
                        ),
                      ),
                      child: Builder(
                        builder: (context) {
                          final brand = Semantics(
                            label: 'Ryhze Games',
                            button: true,
                            child: InkWell(
                              onTap: () => navigate('games'),
                              borderRadius: BorderRadius.circular(8),
                              child: BetaBrand(
                                compact: mobile,
                                width: mobile ? (width <= 350 ? 34 : 40) : 124,
                              ),
                            ),
                          );
                          final actions = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (width > 480 &&
                                  widget.gameLibrary?.isLinux == true)
                                Pill(
                                  bigPicture
                                      ? 'Exit Big Picture'
                                      : 'Big Picture',
                                  icon: bigPicture
                                      ? Icons.fullscreen_exit
                                      : Icons.fullscreen,
                                  iconOnly: true,
                                  onPressed: () => setBigPicture(!bigPicture),
                                ),
                              if (width > 480 && state.catalogueUpdateAvailable)
                                Pill(
                                  'Apply catalogue update',
                                  icon: Icons.refresh,
                                  iconOnly: true,
                                  onPressed: state.applyCatalogueUpdate,
                                ),
                              if (width > 480)
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
                              if (width > 480)
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
                              if (width > 480) const SizedBox(width: 10),
                              if (width > 480)
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
                          );
                          final tabs = BrowseTabs(
                            page: page,
                            onChanged: navigate,
                            engineAvailable: state.engineAccess,
                          );
                          return Row(
                            children: [
                              brand,
                              SizedBox(
                                width: width <= 480
                                    ? 8
                                    : mobile
                                    ? 15
                                    : width <= 1000
                                    ? 20
                                    : 30,
                              ),
                              tabs,
                              const Spacer(),
                              actions,
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  if (widget.updates?.supported == true)
                    UpdateBanner(updates: widget.updates!, onOpen: showUpdates),
                  if (state.loading) const StatusProgress(),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, viewport) => SingleChildScrollView(
                        controller: scroll,
                        child: AnimatedSwitcher(
                          duration: Duration(
                            milliseconds: MotionSettings.of(context) ? 0 : 320,
                          ),
                          layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              for (final child in previous)
                                ExcludeFocus(
                                  child: IgnorePointer(
                                    child: ExcludeSemantics(
                                      child: HeroMode(
                                        enabled: false,
                                        child: child,
                                      ),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if ([
                                  'games',
                                  'films',
                                  'saved',
                                  'history',
                                  'library',
                                  'film-library',
                                ].contains(page))
                                  library(width, gutter, size.maxHeight)
                                else if (page == 'login' || page == 'activate')
                                  AuthPage(
                                    state: state,
                                    activation: page == 'activate',
                                    automaticWebsiteSignIn:
                                        page == 'login' && automaticWebsiteSignIn,
                                    onNavigate: navigate,
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
                                  EditorialPage(page: page, navigate: navigate),
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
  );
  Widget library(double width, double gutter, double height) {
    if (['library', 'film-library', 'saved', 'history'].contains(page)) {
      final kind = page == 'film-library' || page == 'history'
          ? 'film'
          : 'game';
      return PersonalLibrary(
        key: ValueKey('personal-${state.scope}-$kind'),
        state: state,
        kind: kind,
        horizontalPadding: gutter,
        bigPicture: bigPicture,
        initialFilter: page == 'saved'
            ? 'favorite'
            : page == 'history'
            ? 'continue'
            : null,
        games: widget.gameLibrary,
        titleCard: titleCard,
        onOtherLibrary: () =>
            navigate(kind == 'game' ? 'film-library' : 'library'),
        localCard: (game, options) => LocalGameCard(
          libraryOptions: options,
          game: game,
          library: widget.gameLibrary!,
          media: gameMedia!,
          state: state,
          previewAllowed: !detailOpen && !overlayOpen,
          onDetailsChanged: (open) {
            if (mounted) {
              setState(() => detailOpen = open);
              unawaited(syncAudio());
            }
          },
        ),
      );
    }
    return catalogueLibrary(width, gutter, height);
  }

  Widget catalogueLibrary(double width, double gutter, double height) {
    final downloaded = page == 'library';
    final isGames = page == 'games' || downloaded;
    final categories = {
      'All games',
      'Installed games',
      for (final t in state.visibleTitles.where((t) => t.isGame))
        ...t.categories,
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
    final items = state.visibleTitles
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
    final count = items.length + local.length;
    final personal = page == 'saved' || page == 'history';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            gutter,
            bigPicture
                ? 20
                : width <= 700
                ? 22
                : 40,
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
                        Text(
                          downloaded
                              ? 'Your library.'
                              : page == 'saved'
                              ? 'Favourites.'
                              : page == 'history'
                              ? 'Continue watching.'
                              : page == 'films'
                              ? 'Films'
                              : 'Games',
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
              if (isGames && !downloaded && state.publishingAccess)
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
                            child: PopupMenuButton<String>(
                              key: const ValueKey('game-category-select'),
                              tooltip: 'Category',
                              initialValue: category,
                              clipBehavior: Clip.antiAlias,
                              position: PopupMenuPosition.over,
                              constraints: const BoxConstraints(minWidth: 250),
                              itemBuilder: (_) => [
                                for (final value in categories)
                                  RyhzeMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                              ],
                              onSelected: (value) =>
                                  setState(() => gameCategory = value),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                ),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(category)),
                                    const Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
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
                    child: StatusProgress(),
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
                      : 'No titles in this view.',
                  personal
                      ? 'Explore a title and add it to Favourites, or start watching a film.'
                      : 'No films are available for your current account and view. Your saved library is still available.',
                  personal ? 'Browse games' : 'Films Library',
                  () => navigate(personal ? 'games' : 'film-library'),
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
                    final cards = <Widget>[
                      for (final title in items)
                        KeyedSubtree(
                          key: ValueKey('catalogue-${title.id}'),
                          child: titleCard(title),
                        ),
                      for (final game in local)
                        LocalGameCard(
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
                    ];
                    if (bigPicture && isGames) {
                      return GameShelf(children: cards);
                    }
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final card in cards)
                          SizedBox(width: cardWidth, child: card),
                      ],
                    );
                  },
                ),
              if (downloaded && state.engineAccess) ...[
                const SizedBox(height: 40),
                Text('Engine', style: heading(28)),
                const SizedBox(height: 24),
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
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width:
                            (constraints.maxWidth - (columns - 1) * gap) /
                            columns,
                        child: InstalledEngineCard(
                          state: state,
                          onDetailsChanged: engineDetailsChanged,
                        ),
                      ),
                    );
                  },
                ),
              ],
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
  Widget titleCard(
    RyhzeTitle title, [
    Widget? libraryOptions,
  ]) => RyhzeTitleCard(
    title: title,
    state: state,
    progress: !title.isGame && (state.history[title.id]?['duration'] ?? 0) > 0
        ? (state.history[title.id]['position'] as num) /
              (state.history[title.id]['duration'] as num)
        : null,
    previewAllowed: !detailOpen && !overlayOpen,
    onOpen: () => open(title, 'card-${title.id}'),
    onSave: () => save(title),
    trailingAction: libraryOptions != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Pill(
                state.saved.contains(title.id)
                    ? 'Remove favourite'
                    : 'Add favourite',
                iconOnly: true,
                quiet: true,
                icon: state.saved.contains(title.id) ? Icons.check : Icons.add,
                onPressed: () => save(title),
              ),
              libraryOptions,
            ],
          )
        : state.publishingAccess
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
                'Add to Favourites',
                iconOnly: true,
                quiet: true,
                icon: state.saved.contains(title.id) ? Icons.check : Icons.add,
                onPressed: () => save(title),
              ),
            ],
          )
        : null,
  );
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
    final results = widget.state.visibleTitles
        .where((t) => t.matches(query))
        .toList();
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
