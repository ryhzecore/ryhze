import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../core/games.dart';
import '../core/models.dart';
import '../core/state.dart';
import 'design.dart';
import 'player.dart';
import 'artwork_hero.dart';

class DetailPage extends StatelessWidget {
  final RyhzeTitle title;
  final RyhzeState state;
  final String heroTag;
  final VoidCallback onSignIn;
  const DetailPage({
    super.key,
    required this.title,
    required this.state,
    required this.heroTag,
    required this.onSignIn,
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (_, _) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.pop(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (_, c) {
                final mobile = c.maxWidth <= 700;
                final gutter = mobile ? 20.0 : 36.0;
                return Stack(
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
                      child: Container(
                        margin: EdgeInsets.all(mobile ? 12 : 24),
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
                              Container(
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
                                    bottom: BorderSide(
                                      color: Color(0x18ffffff),
                                    ),
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
                                      reduced: state.reduced,
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                    SizedBox(width: mobile ? 12 : 20),
                                    Expanded(
                                      child: Text(
                                        title.label.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: mobile ? 8 : 10,
                                          letterSpacing: 1.2,
                                          color: muted,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: mobile ? 12 : 20),
                                    Pill(
                                      state.saved.contains(title.id)
                                          ? 'Remove from My List'
                                          : 'Add to My List',
                                      iconOnly: true,
                                      icon: state.saved.contains(title.id)
                                          ? Icons.check
                                          : Icons.add,
                                      onPressed: () {
                                        if (state.user == null) {
                                          Navigator.pop(context);
                                          onSignIn();
                                        } else {
                                          attempt(
                                            context,
                                            () => state.toggleSaved(title),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          gutter,
                                          mobile ? 25 : 30,
                                          gutter,
                                          mobile ? 20 : 25,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Eyebrow(title.status),
                                            const SizedBox(height: 12),
                                            Text(
                                              title.title,
                                              style: heading(
                                                c.maxWidth <= 350
                                                    ? 32
                                                    : mobile
                                                    ? 38
                                                    : (c.maxWidth * .045).clamp(
                                                        32,
                                                        62,
                                                      ),
                                              ).copyWith(height: 1.1),
                                            ),
                                            const SizedBox(height: 18),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                for (final tag
                                                    in title.categories)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            99,
                                                          ),
                                                      border: Border.all(
                                                        color: const Color(
                                                          0x26ffffff,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      tag,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: muted,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!title.isGame ||
                                          title.streams.isNotEmpty ||
                                          title.seasons.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: mobile ? 10 : 20,
                                          ),
                                          child: RyhzePlayer(
                                            title: title,
                                            state: state,
                                            heroTag: heroTag,
                                          ),
                                        )
                                      else
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: mobile ? 12 : 20,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              ArtworkHero(
                                                tag: heroTag,
                                                image: title.image,
                                                state: state,
                                                child: ClipRSuperellipse(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        surfaceRadius,
                                                      ),
                                                  child: LayoutBuilder(
                                                    builder:
                                                        (
                                                          context,
                                                          bounds,
                                                        ) => SizedBox(
                                                          width:
                                                              double.infinity,
                                                          height:
                                                              (bounds.maxWidth *
                                                                      9 /
                                                                      16)
                                                                  .clamp(
                                                                    0.0,
                                                                    MediaQuery.sizeOf(
                                                                          context,
                                                                        ).height *
                                                                        .55,
                                                                  ),
                                                          child: TitleArt(
                                                            title.image,
                                                            state,
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                title.imageNote.isEmpty
                                                    ? 'Title artwork'
                                                    : title.imageNote,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          gutter,
                                          mobile ? 25 : 30,
                                          gutter,
                                          mobile ? 25 : 45,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title.id == 'larcenous-driftscape'
                                                  ? 'One state. Every way out.'
                                                  : 'About this title',
                                              style: heading(30),
                                            ),
                                            const SizedBox(height: 20),
                                            Text(title.description),
                                            const SizedBox(height: 28),
                                            Wrap(
                                              spacing: 48,
                                              runSpacing: 24,
                                              children: [
                                                for (final fact in title.facts)
                                                  SizedBox(
                                                    width: 210,
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          fact.label,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 11,
                                                                color: muted,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        Text(
                                                          fact.value,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 14,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 30),
                                            if (title.isGame)
                                              GameOptions(
                                                title: title,
                                                state: state,
                                                onSignIn: () {
                                                  Navigator.pop(context);
                                                  onSignIn();
                                                },
                                              ),
                                            if (title.internal)
                                              const Text(
                                                'Internal test content. This is not a Ryhze production or a public release.',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: muted,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
}

class GameOptions extends StatefulWidget {
  final RyhzeTitle title;
  final RyhzeState state;
  final VoidCallback onSignIn;
  const GameOptions({
    super.key,
    required this.title,
    required this.state,
    required this.onSignIn,
  });
  @override
  State<GameOptions> createState() => _GameOptionsState();
}

class _GameOptionsState extends State<GameOptions> with WidgetsBindingObserver {
  String? riot;
  bool checking = true, downloading = false;
  double? progress;
  File? installer;
  http.Client? downloadClient;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    detect();
  }

  Future<void> detect() async {
    final value = await Games.riotClient();
    if (mounted) {
      setState(() {
        riot = value;
        checking = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) detect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    downloadClient?.close();
    super.dispose();
  }

  Future<void> download() async {
    if (widget.state.user == null) {
      widget.onSignIn();
      return;
    }
    setState(() {
      downloading = true;
      progress = null;
    });
    downloadClient = http.Client();
    try {
      final file = await Games.download(
        widget.state.api,
        widget.title.download!,
        widget.title.id,
        downloadClient!,
        (v) {
          if (mounted) setState(() => progress = v);
        },
      );
      if (mounted) setState(() => installer = file);
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'Download interrupted or unavailable. Please try again.',
        );
      }
    } finally {
      downloadClient?.close();
      if (mounted) setState(() => downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title, state = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.upcoming) ...[
          Pill(
            state.alerts.contains(title.id)
                ? 'Notification on · Cancel'
                : 'Notify Me',
            primary: true,
            onPressed: () => attempt(context, () => state.toggleAlert(title)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Saved on this device. We’ll let you know here when you return and the game is available on Ryhze.',
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ] else if (title.id == 'internal-valorant' && Platform.isWindows) ...[
          if (checking)
            const Text('Checking Riot Client…')
          else if (riot != null)
            Pill(
              'Play',
              icon: Icons.play_arrow_rounded,
              primary: true,
              onPressed: () => attempt(context, () async {
                await Games.launchValorant(riot!);
                if (context.mounted) {
                  toast(context, 'Opening Valorant through Riot Client.');
                }
              }),
            )
          else if (installer != null)
            Pill(
              'Open installer',
              primary: true,
              icon: Icons.open_in_new,
              onPressed: () => attempt(context, () async {
                if (!await launchUrl(Uri.file(installer!.path))) {
                  throw Exception(
                    'Open the installer from your Downloads/Ryhze folder.',
                  );
                }
              }),
            )
          else if (title.download != null)
            Pill(
              downloading ? 'Downloading…' : 'Install',
              primary: true,
              icon: Icons.download_outlined,
              onPressed: downloading ? null : download,
            ),
          if (downloading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: LinearProgressIndicator(value: progress),
            ),
          const SizedBox(height: 12),
          const Text(
            'Riot Client manages installation, updates, and your Riot account.',
            style: TextStyle(fontSize: 11, color: muted),
          ),
          TextButton(
            onPressed: detect,
            child: const Text(
              'Check installation again',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ] else if (title.id == 'internal-valorant') ...[
          const Text(
            'Valorant’s desktop launcher is available in Ryhze for Windows.',
          ),
          const SizedBox(height: 12),
          Pill(
            'Visit Riot Games',
            icon: Icons.open_in_new,
            onPressed: () => attempt(context, () async {
              if (!await launchUrl(
                Uri.parse('https://playvalorant.com/'),
                mode: LaunchMode.externalApplication,
              )) {
                throw Exception('Unable to open the browser.');
              }
            }),
          ),
        ] else if (title.download != null && Platform.isWindows)
          Pill(
            downloading ? 'Downloading…' : 'Download game',
            onPressed: downloading ? null : download,
          )
        else if (title.availability != 'available')
          const Text(
            'This game is in development. There is no playable build available yet.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
      ],
    );
  }
}
