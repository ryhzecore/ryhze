import 'package:flutter/material.dart';
import '../core/ai.dart';
import 'design.dart';
import 'option_menu.dart';

class AiCard extends StatelessWidget {
  final Widget child;
  const AiCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xff111115),
      borderRadius: BorderRadius.circular(surfaceRadius),
      border: Border.all(color: const Color(0x26ffffff)),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

Widget aiChoice(
  String label,
  String value,
  Map<String, String> options,
  ValueChanged<String>? changed,
) => RyhzeDropdown<String>(
  value: options.containsKey(value) ? value : options.keys.first,
  isExpanded: true,
  decoration: InputDecoration(labelText: label),
  items: options.entries
      .map(
        (e) => DropdownMenuItem(
          value: e.key,
          child: Text(e.value, overflow: TextOverflow.ellipsis),
        ),
      )
      .toList(),
  onChanged: changed == null
      ? null
      : (v) {
          if (v != null) changed(v);
        },
);
Map<String, String> aiProjects(RyhzeAi ai) => {
  '': 'All Ryhze',
  for (final p in ai.projects) aiText(p['id']): aiText(p['title']),
};

class AiField {
  final String name, label, value;
  final int limit, lines;
  final bool secret, required;
  final Map<String, String>? choices;
  const AiField(
    this.name,
    this.label, {
    this.value = '',
    this.limit = 4000,
    this.lines = 1,
    this.secret = false,
    this.required = false,
    this.choices,
  });
}

/// Preserve drafts on failures; hide them immediately when access is revoked.
Future<bool?> aiEdit(
  BuildContext context,
  RyhzeAi ai, {
  required String title,
  required List<AiField> fields,
  required Future<void> Function(Map<String, String>) save,
  String explanation = '',
  String action = 'Save',
}) => showDialog<bool>(
  context: context,
  builder: (_) => _AiEditor(
    ai: ai,
    title: title,
    fields: fields,
    save: save,
    explanation: explanation,
    action: action,
  ),
);

class _AiEditor extends StatefulWidget {
  final RyhzeAi ai;
  final String title, explanation, action;
  final List<AiField> fields;
  final Future<void> Function(Map<String, String>) save;
  const _AiEditor({
    required this.ai,
    required this.title,
    required this.fields,
    required this.save,
    required this.explanation,
    required this.action,
  });
  @override
  State<_AiEditor> createState() => _AiEditorState();
}

class _AiEditorState extends State<_AiEditor> {
  late final controllers = {
    for (final f in widget.fields) f.name: TextEditingController(text: f.value),
  };
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.clear();
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !widget.ai.allowed) return;
    final values = {for (final e in controllers.entries) e.key: e.value.text};
    if (widget.fields.any(
      (f) => f.required && values[f.name]!.trim().isEmpty,
    )) {
      setState(() => error = 'Complete the required fields.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.save(values);
      if (mounted && widget.ai.allowed) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ai,
    builder: (context, _) => AlertDialog(
      title: Text(widget.ai.allowed ? widget.title : 'AI access ended'),
      content: SizedBox(
        width: 560,
        child: !widget.ai.allowed
            ? const Text(
                'Close this window and sign in with your approved account.',
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.explanation.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(widget.explanation),
                      ),
                    for (final f in widget.fields)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: f.choices != null
                            ? aiChoice(
                                f.label,
                                controllers[f.name]!.text,
                                f.choices!,
                                busy
                                    ? null
                                    : (v) => setState(
                                        () => controllers[f.name]!.text = v,
                                      ),
                              )
                            : TextField(
                                controller: controllers[f.name],
                                enabled: !busy,
                                obscureText: f.secret,
                                autocorrect: !f.secret,
                                enableSuggestions: !f.secret,
                                minLines: f.lines,
                                maxLines: f.lines == 1 ? 1 : f.lines + 3,
                                maxLength: f.limit,
                                decoration: InputDecoration(
                                  labelText: f.label,
                                  alignLabelWithHint: true,
                                ),
                              ),
                      ),
                    if (error != null)
                      Text(error!, style: const TextStyle(color: Colors.amber)),
                    if (busy) const StatusProgress(label: 'Saving'),
                  ],
                ),
              ),
      ),
      actions: [
        Pill(
          'Close',
          onPressed: busy && widget.ai.allowed
              ? null
              : () => Navigator.pop(context, false),
        ),
        if (widget.ai.allowed)
          Pill(widget.action, primary: true, onPressed: busy ? null : save),
      ],
    ),
  );
}
