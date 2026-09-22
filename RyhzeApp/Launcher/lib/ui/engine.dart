import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models.dart';
import 'artwork_hero.dart';
import 'title_card.dart';
import '../core/state.dart';
import 'design.dart';
import 'engine_versions.dart';
import 'engine_editor.dart';
import 'dart:ui' show ImageFilter;
import '../core/race_installation.dart';
export '../core/race_installation.dart' show raceInstallation;

class RaceArtwork extends StatelessWidget {
  const RaceArtwork({super.key});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xff38205f), Color(0xff15121e), Color(0xff08090c)],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.view_in_ar_outlined,
        size: 112,
        color: Colors.white.withValues(alpha: .72),
      ),
    ),
  );
}

class RaceThumbnail extends StatelessWidget {
  final RyhzeState state;
  const RaceThumbnail({super.key, required this.state});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (_, _) => state.engineThumbnail == null
        ? const RaceArtwork()
        : TitleArt(state.engineThumbnail!['url'], state),
  );
}

class EngineCataloguePage extends StatelessWidget {
  final RyhzeState state;
  final double horizontalPadding;
  final ValueChanged<bool>? onDetailsChanged;
  const EngineCataloguePage({
    super.key,
    required this.state,
    required this.horizontalPadding,
    this.onDetailsChanged,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 40),
    child: LayoutBuilder(
      builder: (context, bounds) {
        final columns = bounds.maxWidth < 650
            ? 1
            : bounds.maxWidth < 1050
            ? 2
            : 3;
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: (bounds.maxWidth - (columns - 1) * 24) / columns,
            child: InstalledEngineCard(
              state: state,
              onDetailsChanged: onDetailsChanged,
            ),
          ),
        );
      },
    ),
  );
}

class RaceDetail extends StatelessWidget {
  final RyhzeState state;
  final String? uninstallRequested;
  const RaceDetail({super.key, required this.state, this.uninstallRequested});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      if (!state.engineAccess) return const SizedBox.shrink();
      final mobile = MediaQuery.sizeOf(context).width <= 700;
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.pop(context),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(context),
                      child: BackdropFilter(
                        enabled: !GameFrameMotion.ownsFrame(context),
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(mobile ? 12 : 24),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1080),
                        decoration: ShapeDecoration(
                          color: GameFrameMotion.ownsFrame(context)
                              ? Colors.transparent
                              : const Color(0xd9111014),
                          shape: RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(
                              panelRadius(mobile),
                            ),
                            side: BorderSide(
                              color: GameFrameMotion.ownsFrame(context)
                                  ? Colors.transparent
                                  : const Color(0x25ffffff),
                            ),
                          ),
                        ),
                        child: ClipRSuperellipse(
                          borderRadius: BorderRadius.circular(
                            panelRadius(mobile),
                          ),
                          child: Column(
                            children: [
                              DetailControlsReveal(
                                child: Container(
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
                                      bottom: BorderSide(
                                        color: Color(0x18ffffff),
                                      ),
                                    ),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: detailGutter(mobile),
                                    vertical: detailGutter(mobile),
                                  ),
                                  child: Row(
                                    children: [
                                      Pill(
                                        'Back',
                                        height: 44,
                                        icon: Icons.arrow_back,
                                        iconFirst: true,
                                        backStyle: true,
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                      const SizedBox(width: 20),
                                      const Expanded(
                                        child: Eyebrow('Ryhze Engine'),
                                      ),
                                      if (state.adminAccess)
                                        Pill(
                                          'Manage versions',
                                          height: 44,
                                          icon: Icons.edit_outlined,
                                          iconOnly: true,
                                          onPressed: () =>
                                              Navigator.of(context).push(
                                                MaterialPageRoute<void>(
                                                  builder: (_) => EngineEditor(
                                                    state: state,
                                                    selectedId: state.prefs
                                                        .getString(
                                                          'race-selected-build',
                                                        ),
                                                  ),
                                                ),
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      detailGutter(mobile),
                                      detailGutter(mobile),
                                      detailGutter(mobile),
                                      detailGutter(mobile),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        DetailControlsReveal(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 24,
                                            ),
                                            child: Text(
                                              'RACE',
                                              style: heading(
                                                detailTitleSize(
                                                  MediaQuery.sizeOf(
                                                    context,
                                                  ).width,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        EnginePage(
                                          key: ValueKey(
                                            state.engineCatalogueRevision,
                                          ),
                                          state: state,
                                          horizontalPadding: 0,
                                          embedded: true,
                                          uninstallRequested:
                                              uninstallRequested,
                                          artworkBuilder: (build) => ArtworkHero(
                                            tag: 'card-race-engine',
                                            image:
                                                state.engineThumbnail?['url'] ??
                                                '',
                                            state: state,
                                            artwork: RaceThumbnail(
                                              state: state,
                                            ),
                                            child: ClipRSuperellipse(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    surfaceRadius,
                                                  ),
                                              child: AspectRatio(
                                                aspectRatio: artworkAspectRatio(
                                                  MediaQuery.sizeOf(
                                                    context,
                                                  ).width,
                                                ),
                                                child: RaceThumbnail(
                                                  state: state,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
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
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class InstalledEngineCard extends StatefulWidget {
  final RyhzeState state;
  final ValueChanged<bool>? onDetailsChanged;
  const InstalledEngineCard({
    super.key,
    required this.state,
    this.onDetailsChanged,
  });
  @override
  State<InstalledEngineCard> createState() => _InstalledEngineCardState();
}

class _InstalledEngineCardState extends State<InstalledEngineCard>
    with WidgetsBindingObserver {
  late Future<Map<String, dynamic>?> installation;
  Timer? refreshTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.state.refreshEngineThumbnail());
    installation = raceInstallation(
      directory: widget.state.prefs.getString(raceDirectoryKey),
    );
    refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => refresh(),
    );
  }

  void refresh() {
    if (!mounted || !widget.state.engineAccess) return;
    setState(() {
      installation = raceInstallation(
        directory: widget.state.prefs.getString(raceDirectoryKey),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    if (value == AppLifecycleState.resumed) refresh();
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> openDetails() async {
    if (!widget.state.engineAccess) return;
    final source = artworkBounds(context, 'card-race-engine');
    widget.onDetailsChanged?.call(true);
    try {
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          opaque: false,
          barrierDismissible: true,
          barrierLabel: 'Close RACE details',
          barrierColor: Colors.black.withValues(alpha: .7),
          transitionDuration: Duration(
            milliseconds: widget.state.reduced
                ? 0
                : artworkTransitionMilliseconds,
          ),
          reverseTransitionDuration: Duration(
            milliseconds: widget.state.reduced
                ? 0
                : artworkTransitionMilliseconds,
          ),
          pageBuilder: (_, _, _) => RaceDetail(state: widget.state),
          transitionsBuilder: (_, animation, _, child) => GameFrameTransition(
            animation: animation,
            source: source,
            reduced: widget.state.reduced || MotionSettings.of(context),
            child: child,
          ),
        ),
      );
    } finally {
      widget.onDetailsChanged?.call(false);
      refresh();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: installation,
    builder: (context, snapshot) {
      if (!widget.state.engineAccess) {
        return const SizedBox.shrink();
      }
      final title = RyhzeTitle(
        id: 'race-engine',
        title: 'RACE',
        kind: 'game',
        image: widget.state.engineThumbnail?['url'] ?? '',
        label: 'Ryhze Engine',
        status: snapshot.data != null ? 'Installed' : 'Engine',
        description: '',
        categories: [
          snapshot.data != null
              ? 'Version ${snapshot.data?['version']}'
              : 'Install or locate',
        ],
      );
      return RyhzeTitleCard(
        title: title,
        state: widget.state,
        artwork: RaceThumbnail(state: widget.state),
        onOpen: openDetails,
        onSave: openDetails,
      );
    },
  );
}

class EnginePage extends StatelessWidget {
  final RyhzeState state;
  final double? horizontalPadding;
  final bool embedded;
  final String? uninstallRequested;
  final Widget Function(EngineBuild?)? artworkBuilder;
  const EnginePage({
    super.key,
    required this.state,
    this.horizontalPadding,
    this.embedded = false,
    this.uninstallRequested,
    this.artworkBuilder,
  });
  @override
  Widget build(BuildContext context) {
    final content = EngineVersions(
      state: state,
      horizontalPadding: horizontalPadding,
      embedded: embedded,
      uninstallRequested: uninstallRequested,
      artworkBuilder: artworkBuilder,
    );
    if (embedded) return content;
    return LayoutBuilder(
      builder: (_, bounds) => bounds.hasBoundedHeight
          ? SingleChildScrollView(child: content)
          : content,
    );
  }
}
