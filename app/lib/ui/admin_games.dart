import 'package:flutter/material.dart';
import '../core/state.dart';
import '../core/models.dart';
import 'design.dart';

Future<void> editCatalogueGame(
  BuildContext context,
  RyhzeState state, [
  RyhzeTitle? title,
]) async {
  if (state.user?.launcherAdmin != true) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _GameEditor(state: state, title: title),
  );
}

class _GameEditor extends StatefulWidget {
  final RyhzeState state;
  final RyhzeTitle? title;
  const _GameEditor({required this.state, this.title});
  @override
  State<_GameEditor> createState() => _GameEditorState();
}

class _GameEditorState extends State<_GameEditor> {
  bool get existing => widget.state.titles.any((t) => t.id == widget.title?.id);
  final form = GlobalKey<FormState>();
  late final fields = <String, TextEditingController>{
    'id': TextEditingController(text: widget.title?.id),
    'title': TextEditingController(text: widget.title?.title),
    'label': TextEditingController(text: widget.title?.label ?? 'Ryhze Games'),
    'status': TextEditingController(text: widget.title?.status ?? 'Available'),
    'description': TextEditingController(text: widget.title?.description),
    'image': TextEditingController(text: widget.title?.image),
    'imageNote': TextEditingController(text: widget.title?.imageNote),
    'categories': TextEditingController(
      text: widget.title?.categories.join(', '),
    ),
    'storeId': TextEditingController(text: widget.title?.storeId),
  };
  bool saving = false;
  String? error;
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save({bool hidden = false}) async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.state.api.request(
        '/api/admin/games',
        body: {
          for (final entry in fields.entries)
            entry.key: entry.value.text.trim(),
          'categories': fields['categories']!.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
          'revision': widget.title?.revision ?? 0,
          'hidden': hidden,
        },
      );
      await widget.state.refresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(existing ? 'Edit game' : 'Add game'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Saved changes update the shared Ryhze catalogue.'),
              for (final entry in fields.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: TextFormField(
                    controller: entry.value,
                    readOnly: entry.key == 'id' && existing,
                    maxLines: entry.key == 'description' ? 4 : 1,
                    decoration: InputDecoration(
                      labelText: const {
                        'id': 'Game ID',
                        'title': 'Title',
                        'label': 'Publisher / studio',
                        'status': 'Status',
                        'description': 'Description',
                        'image': 'Artwork path (/art/...)',
                        'imageNote': 'Artwork caption',
                        'categories': 'Categories (comma separated)',
                        'storeId': 'Steam app ID (optional)',
                      }[entry.key],
                    ),
                    validator: (value) =>
                        ['id', 'title'].contains(entry.key) &&
                            (value?.trim().isEmpty ?? true)
                        ? 'Required'
                        : null,
                  ),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      if (existing)
        TextButton(
          onPressed: saving ? null : () => save(hidden: true),
          child: const Text('Remove from catalogue'),
        ),
      Pill(
        saving ? 'Saving…' : 'Save game',
        primary: true,
        onPressed: saving ? null : save,
      ),
    ],
  );
}
