import 'package:flutter/material.dart';
import '../core/state.dart';
import 'design.dart';
import 'option_menu.dart';
import 'publishing_upload.dart';

class EngineEditor extends StatefulWidget {
  final RyhzeState state;
  final String? selectedId;
  const EngineEditor({super.key, required this.state, this.selectedId});
  @override
  State<EngineEditor> createState() => _EngineEditorState();
}

class _EngineEditorState extends State<EngineEditor> {
  late final account = widget.state.scope;
  final id = TextEditingController(),
      version = TextEditingController(),
      number = TextEditingController(),
      title = TextEditingController(),
      notes = TextEditingController();
  List<Map<String, dynamic>> releases = [], media = [];
  Map<String, dynamic>? selected, thumbnail;
  String? packageId, message;
  int revision = 0;
  bool busy = true, loaded = false, removeDemo = false;
  bool get allowed => widget.state.adminAccess && widget.state.scope == account;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final c in [id, version, number, title, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      final data = await widget.state.api.request('/api/admin/engine');
      if (!mounted || !allowed) return;
      revision = data['revision'];
      releases = (data['releases'] as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      thumbnail = data['thumbnail'] == null
          ? null
          : Map<String, dynamic>.from(data['thumbnail']);
      choose(
        releases.where((r) => r['id'] == widget.selectedId).firstOrNull ??
            releases.firstOrNull,
      );
      loaded = true;
    } catch (e) {
      if (mounted) message = '$e';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void choose(Map<String, dynamic>? release) {
    selected = release;
    id.text = release?['id'] ?? '';
    version.text = release?['version'] ?? '';
    number.text = '${release?['buildNumber'] ?? 1}';
    title.text = release?['title'] ?? '';
    notes.text = release?['notes'] ?? '';
    media = ((release?['media'] ?? []) as List)
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    packageId = null;
    removeDemo = false;
    message = null;
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy || !allowed || !loaded) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted && allowed) message = '$e';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> change(Map<String, dynamic> body) async {
    if (!allowed) throw StateError('Administrator access is off.');
    final result = await widget.state.api.request(
      '/api/admin/engine',
      body: {...body, 'revision': revision},
      timeout: const Duration(minutes: 2),
    );
    if (!mounted || !allowed) return;
    revision = result['revision'];
    if (body['action'] != 'thumbnail') widget.state.engineCatalogueChanged();
  }

  Future<void> upload(String target) => run(() async {
    final result = await uploadPublishingFile(
      context,
      widget.state,
      'race-engine',
      target,
      (text) {
        if (mounted && allowed) setState(() => message = text);
      },
      engine: true,
    );
    if (result == null || !mounted || !allowed) return;
    if (target == 'package') {
      packageId = result['id'];
      message =
          'Package uploaded and verified. Save the version to make it available.';
    } else if (target == 'thumbnail') {
      await change({'action': 'thumbnail', 'assetId': result['id']});
      if (!mounted || !allowed) return;
      thumbnail = {
        ...result,
        'url': '/api/engine/releases/media/${result['id']}',
      };
      widget.state.setEngineThumbnail(thumbnail);
      message = 'Main thumbnail saved.';
    } else {
      media.add({
        ...result,
        'title': result['title'] ?? (target == 'preview' ? 'Video' : 'Image'),
        'mime': target == 'preview' ? 'video/mp4' : 'image/jpeg',
      });
      message = 'Media added. Save the version to apply it.';
    }
  });
  Future<void> save() => run(() async {
    if (title.text.trim().isEmpty) throw StateError('Enter a version title.');
    if (selected == null && packageId == null) {
      throw StateError('Upload the packaged ZIP first.');
    }
    await change({
      'action': 'save',
      'id': id.text.trim(),
      'version': version.text.trim(),
      'buildNumber': selected != null
          ? selected!['buildNumber']
          : int.tryParse(number.text),
      'title': title.text.trim(),
      'notes': notes.text,
      'assetId': packageId,
      'removeLegacyDemo': removeDemo,
      'media': media
          .map(
            (m) => {
              'id': m['id'],
              'kind': (m['mime'] as String).startsWith('video/')
                  ? 'video'
                  : 'image',
            },
          )
          .toList(),
    });
    if (mounted && allowed) Navigator.pop(context, true);
  });
  Future<void> delete() async {
    if (busy || selected == null || !allowed) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => ListenableBuilder(
        listenable: widget.state,
        builder: (_, _) => RyhzeAlertDialog(
          title: const Text('Delete selected version?'),
          content: Text(
            allowed
                ? '${selected!['title'] ?? selected!['version']} will be removed from the catalogue. When Ryhze opens, users with this version installed will be asked to proceed with uninstalling. Project files are preserved.'
                : 'Administrator access is off.',
          ),
          actions: [
            Pill('Cancel', onPressed: () => Navigator.pop(dialog, false)),
            if (allowed)
              Pill(
                'Delete version',
                onPressed: () => Navigator.pop(dialog, true),
              ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted || !allowed) return;
    await run(() async {
      await change({'action': 'delete', 'id': selected!['id']});
      if (mounted && allowed) Navigator.pop(context, true);
    });
  }

  Widget field(
    String label,
    TextEditingController controller, {
    bool enabled = true,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextField(
      controller: controller,
      enabled: !busy && enabled,
      minLines: lines,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: lines > 1,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.state,
    builder: (context, _) => Scaffold(
      backgroundColor: canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListView(
              padding: EdgeInsets.all(
                detailGutter(MediaQuery.sizeOf(context).width <= 700),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Pill(
                    'Back',
                    icon: Icons.arrow_back,
                    iconFirst: true,
                    backStyle: true,
                    onPressed: busy && allowed
                        ? null
                        : () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Manage RACE versions', style: heading(30)),
                const SizedBox(height: 24),
                if (!allowed)
                  const Text('Administrator access is off.')
                else ...[
                  if (busy)
                    StatusProgress(
                      label: message?.isNotEmpty == true
                          ? message!
                          : 'Loading engine editor',
                    ),
                  if (!busy && message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Text(message!),
                    ),
                  if (!loaded && !busy)
                    Pill(
                      'Retry',
                      onPressed: () {
                        setState(() => busy = true);
                        load();
                      },
                    ),
                  if (loaded) ...[
                    Text('Main thumbnail', style: heading(22)),
                    const SizedBox(height: 8),
                    const Text(
                      'Used on the engine card and first in the opened menu. Version media appears after it.',
                    ),
                    const SizedBox(height: 12),
                    if (thumbnail != null)
                      SizedBox(
                        height: 140,
                        child: ClipRSuperellipse(
                          borderRadius: BorderRadius.circular(surfaceRadius),
                          child: TitleArt(thumbnail!['url'], widget.state),
                        ),
                      ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        Pill(
                          'Upload main thumbnail',
                          icon: Icons.image_outlined,
                          onPressed: busy ? null : () => upload('thumbnail'),
                        ),
                        if (thumbnail != null)
                          Pill(
                            'Remove thumbnail',
                            onPressed: busy
                                ? null
                                : () => run(() async {
                                    await change({
                                      'action': 'thumbnail',
                                      'assetId': null,
                                    });
                                    if (!mounted || !allowed) return;
                                    thumbnail = null;
                                    widget.state.setEngineThumbnail(null);
                                    message = 'Main thumbnail removed.';
                                  }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    RyhzeDropdown<String>(
                      value: selected?['id'],
                      fullWidthMenu: true,
                      isExpanded: true,
                      hint: const Text('New version'),
                      items: releases
                          .map(
                            (r) => DropdownMenuItem<String>(
                              value: r['id'],
                              child: Text(
                                '${r['displayVersion'] ?? r['version']} · ${r['title'] ?? 'RACE'}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (value) => setState(
                              () => choose(
                                releases.firstWhere((r) => r['id'] == value),
                              ),
                            ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        Pill(
                          'Add version',
                          icon: Icons.add,
                          onPressed: busy
                              ? null
                              : () => setState(() => choose(null)),
                        ),
                        if (selected != null)
                          Pill(
                            'Delete selected version',
                            icon: Icons.delete_outline,
                            onPressed: busy ? null : delete,
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    field('Version title', title),
                    field(
                      'Version number (for example 0.0.8)',
                      version,
                      enabled: selected == null,
                    ),
                    field('Build number', number, enabled: selected == null),
                    if (selected == null) ...[
                      field('Release ID / folder inside ZIP', id),
                      const Text(
                        'The ZIP must contain <release ID>/RACE.exe and its supporting files.',
                      ),
                      const SizedBox(height: 12),
                      Pill(
                        packageId == null
                            ? 'Upload packaged ZIP'
                            : 'Replace uploaded ZIP',
                        icon: Icons.upload_file,
                        onPressed: busy ? null : () => upload('package'),
                      ),
                      const SizedBox(height: 18),
                    ],
                    field('Version description', notes, lines: 5),
                    Text('Version images and videos', style: heading(22)),
                    const SizedBox(height: 12),
                    if (selected?['demo'] != null && !removeDemo)
                      Row(
                        children: [
                          const Expanded(child: Text('Existing tech demo')),
                          Pill(
                            'Remove existing demo',
                            iconOnly: true,
                            icon: Icons.remove,
                            onPressed: busy
                                ? null
                                : () => setState(() => removeDemo = true),
                          ),
                        ],
                      ),
                    for (var i = 0; i < media.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(
                              (media[i]['mime'] as String).startsWith('video/')
                                  ? Icons.movie_outlined
                                  : Icons.image_outlined,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('${i + 2}. ${media[i]['title']}'),
                            ),
                            Pill(
                              'Move media earlier',
                              iconOnly: true,
                              icon: Icons.arrow_upward,
                              onPressed: busy || i == 0
                                  ? null
                                  : () => setState(() {
                                      final item = media.removeAt(i);
                                      media.insert(i - 1, item);
                                    }),
                            ),
                            const SizedBox(width: 8),
                            Pill(
                              'Remove media',
                              iconOnly: true,
                              icon: Icons.remove,
                              onPressed: busy
                                  ? null
                                  : () => setState(() => media.removeAt(i)),
                            ),
                          ],
                        ),
                      ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        Pill(
                          'Add image',
                          icon: Icons.add_photo_alternate_outlined,
                          onPressed: busy || media.length >= 20
                              ? null
                              : () => upload('image'),
                        ),
                        Pill(
                          'Add video',
                          icon: Icons.video_library_outlined,
                          onPressed: busy || media.length >= 20
                              ? null
                              : () => upload('preview'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Pill(
                      'Save version',
                      primary: true,
                      onPressed: busy ? null : save,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
