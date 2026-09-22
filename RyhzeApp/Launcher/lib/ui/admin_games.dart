import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/state.dart';
import '../core/models.dart';
import 'design.dart';
import 'option_menu.dart';
import 'page_header.dart';
import 'publishing_upload.dart';

Future<void> editCatalogueGame(
  BuildContext context,
  RyhzeState state, [
  RyhzeTitle? title,
]) async {
  if (!state.publishingAccess) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => GamePublishingPage(
        state: state,
        gameId: title?.id,
        kind: title?.isGame == false ? 'film' : 'game',
      ),
    ),
  );
}

class GamePublishingPage extends StatefulWidget {
  final RyhzeState state;
  final String? gameId;
  final String kind;
  const GamePublishingPage({
    super.key,
    required this.state,
    this.gameId,
    this.kind = 'game',
  });
  @override
  State<GamePublishingPage> createState() => _GamePublishingPageState();
}

class _GamePublishingPageState extends State<GamePublishingPage> {
  static const base = '/api/admin/publishing';
  final fields = <String, TextEditingController>{
    for (final k in [
      'id',
      'title',
      'label',
      'status',
      'description',
      'image',
      'hero',
      'imageNote',
      'preview',
      'storeId',
      'storeUrl',
      'download',
      'categories',
    ])
      k: TextEditingController(),
  };
  Map<String, dynamic> document = {}, published = {};
  List<dynamic> games = [], history = [], packages = [], uploads = [];
  String progress = '',
      releaseVersion = '',
      releasePlatform = 'windows',
      releaseNotes = '',
      assetId = '';
  int revision = 0;
  bool busy = false, dirty = false;
  String? error;
  String tab = 'Details';
  late String catalogueKind = widget.kind;
  bool get film => catalogueKind == 'film';
  bool get hasSavedTitle =>
      (document['id'] as String? ?? '').isNotEmpty &&
      (revision > 0 || published.isNotEmpty);
  final importLink = TextEditingController();
  List<dynamic> imports = [];
  Timer? importTimer;
  bool pollingImports = false;
  String? importRequestId;
  String importRequestUrl = '';
  String newRequestId() {
    final random = Random.secure();
    final h = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> refreshImports() async {
    if (!film || pollingImports || (document['id'] ?? '').isEmpty) return;
    pollingImports = true;
    final id = document['id'];
    try {
      final jobs = await api('/imports?game=$id');
      if (mounted && document['id'] == id) {
        setState(() => imports = List<dynamic>.from(jobs));
      }
    } catch (_) {
      /* Preserve visible jobs during a connection failure. */
    } finally {
      pollingImports = false;
    }
  }

  Future<void> importFilm() async {
    final url = importLink.text.trim();
    if (Uri.tryParse(url)?.scheme != 'https') {
      throw Exception('Paste a direct HTTPS video file link.');
    }
    await save();
    if (importRequestId == null || importRequestUrl != url) {
      importRequestId = newRequestId();
      importRequestUrl = url;
    }
    await api('/imports', {
      'gameId': document['id'],
      'url': url,
      'requestId': importRequestId,
    });
    importRequestId = null;
    importLink.clear();
    await refreshImports();
  }

  Future<void> related() async {
    if (!mounted || !hasSavedTitle) return;
    final id = document['id'];
    packages = await api('/releases?game=$id');
    uploads = await api('/uploads?game=$id');
  }

  Future<void> upload(String target) async {
    if (!allowed) return;
    await save();
    if (!mounted || !hasSavedTitle) return;
    final r = await uploadPublishingFile(
      context,
      state,
      fields['id']!.text.trim(),
      target,
      (p) {
        if (mounted) setState(() => progress = p);
      },
    );
    if (r == null || !allowed) return;
    document['id'] = fields['id']!.text.trim();
    if (target == 'package') {
      assetId = r['id'];
    } else if (target == 'streams') {
      document['streams'] = [
        ...?document['streams'],
        {'url': r['url'], 'type': '.mp4'},
      ];
      dirty = true;
    } else if (target == 'screenshots') {
      document['screenshots'] = [
        ...?document['screenshots'],
        {'url': r['url'], 'caption': ''},
      ];
      dirty = true;
    } else {
      fields[target]!.text = r['url'];
      dirty = true;
    }
    await related();
  }

  RyhzeState get state => widget.state;
  late final String account = state.scope;
  bool get allowed => state.publishingAccess && state.scope == account;
  void accessChanged() {
    if (!mounted) return;
    if (!allowed) importTimer?.cancel();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    state.addListener(accessChanged);
    reset();
    importTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!busy) unawaited(refreshImports());
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => work(() async {
        await list();
        if (widget.gameId != null) await load(widget.gameId!);
      }),
    );
  }

  void reset() {
    document = {
      'id': '',
      'kind': catalogueKind,
      'title': '',
      'label': film ? 'Ryhze Films' : 'Ryhze Games',
      'status': 'In development',
      'description': '',
      'image': '',
      'hero': '',
      'imageNote': '',
      'preview': '',
      'storeId': '',
      'storeUrl': '',
      'download': '',
      'categories': [],
      'facts': [],
      'screenshots': [],
      'streams': [],
      'releases': [],
      'availability': 'coming-soon',
      'visibility': 'internal',
    };
    published = {};
    history = [];
    packages = [];
    uploads = [];
    assetId = '';
    releaseVersion = '';
    releasePlatform = 'windows';
    releaseNotes = '';
    progress = '';
    error = null;
    tab = 'Details';
    imports = [];
    revision = 0;
    dirty = false;
    fill();
  }

  void fill() {
    for (final e in fields.entries) {
      e.value.text = e.key == 'categories'
          ? (document['categories'] as List? ?? []).join(', ')
          : '${document[e.key] ?? ''}';
    }
  }

  Future<dynamic> api(String path, [Map<String, dynamic>? body]) async {
    if (!allowed) throw StateError('Administrator access is off.');
    final result = await state.api.request(base + path, body: body);
    if (!allowed) throw StateError('Administrator access is off.');
    return result;
  }

  Future<void> work(Future<void> Function() fn) async {
    if (!mounted || !allowed || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await fn();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> list() async {
    final r = await api(film ? '/games?kind=film' : '/games');
    final all = <String, dynamic>{};
    for (final d in [...r['games'], ...r['drafts']]) {
      all[d['id']] = d;
    }
    games = all.values.toList();
  }

  Future<void> load(String id) async {
    if (id.trim().isEmpty) return;
    final r = await api('/games/$id');
    final d = r['draft'] ?? r['published'];
    if (d == null) {
      await list();
      error =
          'This title is no longer available. Choose another title or create a new one.';
      return;
    }
    document = Map<String, dynamic>.from(d);
    catalogueKind = document['kind'] == 'film' ? 'film' : 'game';
    document['visibility'] ??= document['hidden'] == true
        ? 'hidden'
        : document['internal'] == true
        ? 'internal'
        : 'public';
    document['availability'] ??= 'coming-soon';
    published = Map<String, dynamic>.from(r['published'] ?? {});
    revision = r['draft']?['draftRevision'] ?? 0;
    dirty = false;
    assetId = '';
    releaseVersion = '';
    releaseNotes = '';
    packages = [];
    uploads = [];
    history = [];
    fill();
    history = await api('/history?game=$id');
    await related();
    await refreshImports();
  }

  Map<String, dynamic> current() => {
    ...document,
    for (final e in fields.entries)
      e.key: e.key == 'categories'
          ? e.value.text
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList()
          : e.value.text.trim(),
  };
  Future<void> save() async {
    final r = await api('/drafts', {
      'document': current(),
      'revision': revision,
    });
    document = Map<String, dynamic>.from(r['draft']);
    published = Map<String, dynamic>.from(r['published'] ?? {});
    revision = document['draftRevision'];
    dirty = false;
    fill();
    await list();
    if (mounted) toast(context, 'Saved. These changes are not published.');
  }

  Future<void> publish() async {
    if (busy || dirty) return;
    await work(() async {
      await save();
      await related();
    });
    if (!mounted || error != null) return;
    final ready = packages.where((p) => p['state'] == 'verified').toList();
    final selectedBuilds = <String, String>{};
    for (final p in ready) {
      selectedBuilds.putIfAbsent(p['platform'], () => p['id']);
    }

    final changes = current().keys
        .where(
          (k) =>
              ![
                'revision',
                'draftRevision',
                'baseRevision',
                'releases',
              ].contains(k) &&
              jsonEncode(current()[k]) != jsonEncode(published[k]),
        )
        .toList();
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, updateReview) => AlertDialog(
          title: const Text('Publish to Ryhze'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Updates the app and website. Visibility: ${document['visibility']}',
                  ),
                  const SizedBox(height: 20),
                  if (!film) ...[
                    const Text('Game build to publish'),
                    const Text(
                      'Latest verified builds are selected. Choose an older version to revert downloads. Installed games are not downgraded automatically.',
                    ),
                    if (ready.isEmpty)
                      const Text(
                        'No verified builds yet. Upload and register a version in Game releases first. Catalogue changes can still be published.',
                      ),
                    for (final platform in selectedBuilds.keys)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$platform - Live: ${ready.where((p) => p['platform'] == platform && (published['releases'] as List? ?? []).contains(p['id'])).map((p) => p['version']).firstOrNull ?? 'None'}',
                            ),
                            RyhzeDropdown<String>(
                              value: selectedBuilds[platform],
                              isExpanded: true,
                              items: [
                                for (final p in ready.where(
                                  (p) => p['platform'] == platform,
                                ))
                                  DropdownMenuItem(
                                    value: p['id'] as String,
                                    child: Text(
                                      '${p['version']}${ready.firstWhere((r) => r['platform'] == platform)['id'] == p['id'] ? ' - Latest build' : ''}',
                                    ),
                                  ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  updateReview(
                                    () => selectedBuilds[platform] = v,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                  for (final k in changes)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        '$k\nBefore: ${jsonEncode(published[k])}\nAfter: ${jsonEncode(current()[k])}',
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep unpublished'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Publish now'),
            ),
          ],
        ),
      ),
    );
    if (yes != true) return;
    await work(() async {
      await api('/publish', {
        'id': document['id'],
        'revision': revision,
        if (ready.isNotEmpty) 'releaseIds': selectedBuilds.values.toList(),
      });
      await load(document['id']);
      await state.refresh();
      if (mounted) toast(context, 'Published to the app and website.');
    });
  }

  @override
  void dispose() {
    state.removeListener(accessChanged);
    importTimer?.cancel();
    importLink.dispose();
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget streamingEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Film playback', style: heading(22)),
      const SizedBox(height: 12),
      const Text(
        'Import a direct video link. The studio PC downloads and converts it, then uploads a web-ready MP4 to Cloudflare. Queued imports wait while the PC is offline. Use the completed video, then publish your changes.',
      ),
      const SizedBox(height: 16),
      TextField(
        controller: importLink,
        decoration: const InputDecoration(labelText: 'Direct HTTPS video link'),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        children: [
          FilledButton(
            onPressed: busy ? null : () => work(importFilm),
            child: const Text('Import to Cloudflare'),
          ),
          OutlinedButton(
            onPressed: busy ? null : () => work(() => upload('streams')),
            child: const Text('Upload MP4'),
          ),
        ],
      ),
      for (final job in imports)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ([
                'queued',
                'downloading',
                'converting',
                'uploading',
              ].contains(job['state']))
                StatusProgress(
                  label: '${job['state']}',
                  value:
                      job['state'] == 'queued' ||
                          (job['progress'] as num? ?? 0) == 0
                      ? null
                      : (job['progress'] as num).toDouble() / 100,
                )
              else
                Text('${job['state']}'),
              if ((job['error'] ?? '').toString().isNotEmpty)
                Text(job['error']),
              if (job['state'] == 'ready')
                TextButton(
                  onPressed: () => setState(() {
                    final streams = List<dynamic>.from(
                      document['streams'] ?? [],
                    );
                    if (!streams.any((s) => s['url'] == job['url'])) {
                      streams.add({'url': job['url'], 'type': '.mp4'});
                      document['streams'] = streams;
                      dirty = true;
                    }
                  }),
                  child: const Text('Use for playback'),
                ),
            ],
          ),
        ),
      const SizedBox(height: 20),
      for (int i = 0; i < (document['streams'] as List? ?? []).length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ObjectKey(document['streams'][i]),
                  initialValue: document['streams'][i]['url'],
                  decoration: const InputDecoration(
                    labelText: 'Cloudflare playback path',
                  ),
                  onChanged: (v) => setState(() {
                    document['streams'][i]['url'] = v;
                    dirty = true;
                  }),
                ),
              ),
              IconButton(
                tooltip: 'Remove playback source',
                onPressed: () => setState(() {
                  document['streams'].removeAt(i);
                  dirty = true;
                }),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      TextButton(
        onPressed: () => setState(() {
          document['streams'] = [
            ...?document['streams'],
            {'url': ''},
          ];
          dirty = true;
        }),
        child: const Text('Add playback source'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => !allowed
      ? Scaffold(
          appBar: RyhzePageHeader(
            title: 'Ryhze Publishing',
            compact: MediaQuery.sizeOf(context).width <= 700,
          ),
          body: const Center(child: Text('Administrator access is off.')),
        )
      : Scaffold(
          appBar: RyhzePageHeader(
            title: 'Ryhze Publishing',
            compact: MediaQuery.sizeOf(context).width <= 700,
            actions: [
              Pill(
                film ? 'New film' : 'New game',
                icon: Icons.add,
                iconOnly: MediaQuery.sizeOf(context).width <= 480,
                onPressed: busy ? null : () => setState(reset),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text('Prepare once. Publish to the app and website.'),
                    const SizedBox(height: 20),
                    RyhzeDropdown<String>(
                      value: catalogueKind,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'game', child: Text('Games')),
                        DropdownMenuItem(value: 'film', child: Text('Films')),
                      ],
                      onChanged: busy || dirty
                          ? null
                          : (kind) {
                              if (kind != null) {
                                work(() async {
                                  catalogueKind = kind;
                                  reset();
                                  tab = 'Details';
                                  await list();
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 20),
                    RyhzeDropdown<String>(
                      isExpanded: true,
                      fullWidthMenu: true,
                      value: games.any((g) => g['id'] == document['id'])
                          ? document['id']
                          : null,
                      decoration: InputDecoration(
                        labelText: film ? 'Catalogue film' : 'Catalogue game',
                      ),
                      items: games
                          .map(
                            (g) => DropdownMenuItem<String>(
                              value: g['id'],
                              child: Text(g['title']),
                            ),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (id) {
                              if (id != null) work(() => load(id));
                            },
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final name in [
                          'Details',
                          'Media',
                          if (!film) 'Game releases',
                          if (film) 'Streaming',
                          'History',
                          'Preview',
                          'App releases',
                        ])
                          Pill(
                            name,
                            primary: tab == name,
                            onPressed: () => setState(() => tab = name),
                          ),
                      ],
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.orangeAccent),
                        ),
                      ),
                    if (busy || progress.isNotEmpty)
                      StatusProgress(
                        label: progress.isEmpty ? 'Saving' : progress,
                      ),
                    const SizedBox(height: 24),
                    if (tab == 'Details') ...[
                      for (final k in [
                        'id',
                        'title',
                        'label',
                        'status',
                        'description',
                        'categories',
                        if (!film) 'storeId',
                        if (!film) 'storeUrl',
                        if (!film) 'download',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: TextField(
                            controller: fields[k],
                            readOnly:
                                k == 'id' &&
                                (revision > 0 || published.isNotEmpty),
                            maxLines: k == 'description' ? 5 : 1,
                            decoration: InputDecoration(
                              labelText: {
                                'id': film ? 'Film ID' : 'Game ID',
                                'title': film ? 'Film name' : 'Game name',
                                'label': 'Studio / publisher',
                                'status': 'Status',
                                'description': 'Description',
                                'categories': 'Categories, separated by commas',
                                'storeId': 'Steam app ID',
                                'storeUrl': 'Store URL',
                                'download': 'Download URL',
                              }[k],
                            ),
                            onChanged: (_) => setState(() => dirty = true),
                          ),
                        ),
                      RyhzeDropdown<String>(
                        isExpanded: true,
                        fullWidthMenu: true,
                        value: document['visibility'],
                        decoration: const InputDecoration(
                          labelText: 'Visibility',
                        ),
                        items: [
                          for (final s in ['internal', 'public', 'hidden'])
                            DropdownMenuItem(value: s, child: Text(s)),
                        ],
                        onChanged: (s) => setState(() {
                          document['visibility'] = s;
                          dirty = true;
                        }),
                      ),
                      const SizedBox(height: 18),
                      RyhzeDropdown<String>(
                        isExpanded: true,
                        fullWidthMenu: true,
                        value: document['availability'],
                        decoration: const InputDecoration(
                          labelText: 'Availability',
                        ),
                        items: [
                          for (final s in ['coming-soon', 'available'])
                            DropdownMenuItem(value: s, child: Text(s)),
                        ],
                        onChanged: (s) => setState(() {
                          document['availability'] = s;
                          dirty = true;
                        }),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        film ? 'Film facts' : 'Game facts',
                        style: heading(22),
                      ),
                      for (
                        int i = 0;
                        i < (document['facts'] as List? ?? []).length;
                        i++
                      )
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: document['facts'][i]['label'],
                                decoration: const InputDecoration(
                                  labelText: 'Label',
                                ),
                                onChanged: (v) => setState(() {
                                  document['facts'][i]['label'] = v;
                                  dirty = true;
                                }),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: document['facts'][i]['value'],
                                decoration: const InputDecoration(
                                  labelText: 'Value',
                                ),
                                onChanged: (v) => setState(() {
                                  document['facts'][i]['value'] = v;
                                  dirty = true;
                                }),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() {
                                document['facts'].removeAt(i);
                                dirty = true;
                              }),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      TextButton(
                        onPressed: () => setState(() {
                          document['facts'] = [
                            ...?document['facts'],
                            {'label': '', 'value': ''},
                          ];
                          dirty = true;
                        }),
                        child: const Text('Add fact'),
                      ),
                    ],
                    if (tab == 'Media') ...[
                      for (final k in ['image', 'hero', 'preview', 'imageNote'])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: TextField(
                            controller: fields[k],
                            decoration: InputDecoration(
                              labelText: const {
                                'image': 'Cover artwork',
                                'hero': 'Hero artwork',
                                'preview': 'Trailer',
                                'imageNote': 'Artwork caption',
                              }[k],
                            ),
                            onChanged: (_) => setState(() => dirty = true),
                          ),
                        ),
                      Wrap(
                        spacing: 10,
                        children: [
                          for (final e in {
                            'image': 'Upload cover',
                            'hero': 'Upload hero',
                            'screenshots': 'Add screenshot',
                            'preview': 'Upload trailer',
                          }.entries)
                            OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () => work(() => upload(e.key)),
                              child: Text(e.value),
                            ),
                        ],
                      ),
                      for (
                        int i = 0;
                        i < (document['screenshots'] as List? ?? []).length;
                        i++
                      )
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              Image.network(
                                state.api
                                    .resource(document['screenshots'][i]['url'])
                                    .toString(),
                                headers: state.api.authHeaders,
                                width: 100,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.image),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  initialValue:
                                      document['screenshots'][i]['caption'],
                                  decoration: const InputDecoration(
                                    labelText: 'Caption',
                                  ),
                                  onChanged: (v) => setState(() {
                                    document['screenshots'][i]['caption'] = v;
                                    dirty = true;
                                  }),
                                ),
                              ),
                              IconButton(
                                onPressed: i == 0
                                    ? null
                                    : () => setState(() {
                                        final shots =
                                            document['screenshots'] as List;
                                        final s = shots.removeAt(i);
                                        shots.insert(i - 1, s);
                                        dirty = true;
                                      }),
                                icon: const Icon(Icons.arrow_upward),
                              ),
                              IconButton(
                                onPressed: () => setState(() {
                                  document['screenshots'].removeAt(i);
                                  dirty = true;
                                }),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (tab == 'Streaming') streamingEditor(),
                    if (tab == 'Game releases' && !hasSavedTitle)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Choose a catalogue game, or save a new game in Details before adding releases.',
                        ),
                      ),
                    if (tab == 'Game releases' && hasSavedTitle) ...[
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => work(() => upload('package')),
                        child: const Text('Upload game package'),
                      ),
                      const SizedBox(height: 18),
                      RyhzeDropdown<String>(
                        isExpanded: true,
                        fullWidthMenu: true,
                        key: ValueKey(assetId),
                        value: assetId.isEmpty ? null : assetId,
                        decoration: const InputDecoration(
                          labelText: 'Verified package',
                        ),
                        items: uploads
                            .where(
                              (u) =>
                                  u['kind'] == 'package' &&
                                  u['state'] == 'verified',
                            )
                            .map(
                              (u) => DropdownMenuItem<String>(
                                value: u['id'],
                                child: Text(u['filename']),
                              ),
                            )
                            .toList(),
                        onChanged: busy
                            ? null
                            : (s) => setState(() => assetId = s ?? ''),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        key: ValueKey('release-version-${document['id']}'),
                        decoration: const InputDecoration(
                          labelText: 'Version (1.0.0)',
                        ),
                        onChanged: (v) =>
                            setState(() => releaseVersion = v.trim()),
                      ),
                      const SizedBox(height: 18),
                      RyhzeDropdown<String>(
                        isExpanded: true,
                        fullWidthMenu: true,
                        value: releasePlatform,
                        decoration: const InputDecoration(
                          labelText: 'Platform',
                        ),
                        items: [
                          for (final s in [
                            'windows',
                            'android',
                            'linux',
                            'macos',
                          ])
                            DropdownMenuItem(value: s, child: Text(s)),
                        ],
                        onChanged: busy
                            ? null
                            : (v) => setState(() => releasePlatform = v!),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        key: ValueKey('release-notes-${document['id']}'),
                        decoration: const InputDecoration(
                          labelText: 'Release notes',
                        ),
                        maxLines: 3,
                        onChanged: (v) => releaseNotes = v,
                      ),
                      const SizedBox(height: 18),
                      TextButton(
                        onPressed:
                            busy || assetId.isEmpty || releaseVersion.isEmpty
                            ? null
                            : () => work(() async {
                                final r = await api('/releases', {
                                  'gameId': document['id'],
                                  'assetId': assetId,
                                  'version': releaseVersion,
                                  'platform': releasePlatform,
                                  'notes': releaseNotes,
                                });
                                final ids = List<String>.from(
                                  document['releases'] ?? [],
                                );
                                ids.removeWhere(
                                  (id) => packages.any(
                                    (p) =>
                                        p['id'] == id &&
                                        p['platform'] == releasePlatform,
                                  ),
                                );
                                document['releases'] = [...ids, r['id']];
                                dirty = true;
                                await related();
                              }),
                        child: const Text('Register version'),
                      ),
                      const SizedBox(height: 18),
                      for (final p in packages)
                        CheckboxListTile(
                          title: Text('${p['version']} · ${p['platform']}'),
                          subtitle: Text('${p['notes']}\n${p['sha256']}'),
                          value: (document['releases'] as List? ?? []).contains(
                            p['id'],
                          ),
                          onChanged: (v) => setState(() {
                            final values = List<String>.from(
                              document['releases'] ?? [],
                            );
                            if (v == true) {
                              values.removeWhere(
                                (id) => packages.any(
                                  (r) =>
                                      r['id'] == id &&
                                      r['platform'] == p['platform'],
                                ),
                              );
                              values.add(p['id']);
                            } else {
                              values.remove(p['id']);
                            }
                            document['releases'] = values;
                            dirty = true;
                          }),
                        ),
                    ],
                    if (tab == 'History') ...[
                      for (final h in history)
                        ListTile(
                          title: Text(
                            'Revision ${h['revision']} · ${h['document']['title']}',
                          ),
                          subtitle: Text('Published by ${h['published_by']}'),
                          trailing: TextButton(
                            onPressed: busy
                                ? null
                                : () => work(() async {
                                    final r = await api('/restore', {
                                      'id': document['id'],
                                      'historyRevision': h['revision'],
                                      'revision': revision,
                                    });
                                    document = Map<String, dynamic>.from(
                                      r['draft'],
                                    );
                                    revision = document['draftRevision'];
                                    fill();
                                    dirty = false;
                                  }),
                            child: const Text('Restore to draft'),
                          ),
                        ),
                    ],
                    if (tab == 'Preview') ...[
                      const Text('Unpublished content preview'),
                      if (fields['hero']!.text.isNotEmpty ||
                          fields['image']!.text.isNotEmpty)
                        Image.network(
                          state.api
                              .resource(
                                fields['hero']!.text.isNotEmpty
                                    ? fields['hero']!.text
                                    : fields['image']!.text,
                              )
                              .toString(),
                          headers: state.api.authHeaders,
                          height: 300,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Text('Artwork unavailable'),
                        ),
                      Text(fields['title']!.text, style: heading(36)),
                      Text(fields['label']!.text),
                      const SizedBox(height: 20),
                      Text(fields['description']!.text),
                      for (final f in document['facts'] ?? [])
                        ListTile(
                          title: Text(f['label']),
                          subtitle: Text(f['value']),
                        ),
                    ],
                    if (tab == 'App releases') ...[
                      const Text(
                        'Builds and signing run on your private workspace PC. Open its release console over your private network.',
                      ),
                      TextFormField(
                        initialValue:
                            state.prefs.getString('internal-workspace-url') ??
                            '',
                        decoration: const InputDecoration(
                          labelText: 'Private workspace HTTPS address',
                        ),
                        onChanged: (v) =>
                            state.prefs.setString('internal-workspace-url', v),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: () async {
                          final uri = Uri.tryParse(
                            state.prefs.getString('internal-workspace-url') ??
                                '',
                          );
                          if (uri == null ||
                              uri.scheme != 'https' ||
                              !RegExp(
                                r'^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.',
                              ).hasMatch(uri.host) ||
                              uri.userInfo.isNotEmpty) {
                            setState(
                              () => error =
                                  'Enter the HTTPS address of your NetBird workspace PC.',
                            );
                            return;
                          }
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        child: const Text('Open private release console'),
                      ),
                    ],
                    if (tab != 'App releases') ...[
                      const SizedBox(height: 30),
                      Text(
                        dirty
                            ? 'Unsaved changes'
                            : 'Draft revision $revision · ${document['visibility']}',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 14,
                        children: [
                          OutlinedButton(
                            onPressed: busy ? null : () => work(save),
                            child: const Text('Save changes'),
                          ),
                          FilledButton(
                            onPressed: busy || dirty || revision == 0
                                ? null
                                : publish,
                            child: const Text('Review & publish'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
}
