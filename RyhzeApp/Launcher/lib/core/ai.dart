import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'api.dart';
import 'state.dart';

typedef AiObject = Map<String, dynamic>;
AiObject aiObject(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<AiObject> aiList(dynamic value) =>
    value is List ? value.map(aiObject).toList() : [];
bool aiFlag(dynamic value) => value == true || value == 1;
String aiText(dynamic value) => value?.toString() ?? '';

/// Native view state only. Conversations and model execution stay on the
/// authenticated workspace service; no portal HTML, cookies or local chat cache.
class RyhzeAi extends ChangeNotifier {
  final RyhzeState state;
  late final String account = state.scope;
  bool _disposed = false, _revoked = false, _visible = true, _polling = false;
  int _selection = 0, _failures = 0;
  Timer? _poll;
  bool loading = false, sending = false, online = false;
  String? error;
  List<AiObject> chats = [], projects = [];
  AiObject gemini = {};
  AiObject? chat, run, pending;
  String project = '';
  RyhzeAi(this.state) {
    state.addListener(_accountChanged);
  }
  bool get allowed =>
      !_disposed && !_revoked && state.portalAccess && state.scope == account;
  bool get collaborating =>
      gemini['configured'] == true && gemini['assisting'] == true;
  bool get available => online || collaborating;
  bool get running => ['queued', 'running'].contains(run?['status']);
  void changed() {
    if (!_disposed) notifyListeners();
  }

  void _accountChanged() {
    if (!allowed) _revoke();
  }

  void _revoke() {
    _revoked = true;
    _selection++;
    _poll?.cancel();
    chats = [];
    projects = [];
    gemini = {};
    chat = null;
    run = null;
    pending = null;
    error = null;
    sending = false;
    loading = false;
    changed();
  }

  Future<dynamic> call(String path, {AiObject? body, bool slow = false}) async {
    if (!allowed) {
      throw const ApiException(
        'Sign in with your approved account to open AI.',
      );
    }
    try {
      final result = await state.api.request(
        '/portal/internal-api$path',
        body: body,
        timeout: Duration(seconds: slow ? 300 : 20),
      );
      if (!allowed) throw const ApiException('Your AI session ended.');
      return result;
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) _revoke();
      rethrow;
    }
  }

  Future<void> refresh() async {
    if (!allowed || loading) return;
    loading = true;
    error = null;
    changed();
    // Independent failures must not discard usable conversation history.
    await Future.wait([
      _load('/ai/chats', (v) => chats = aiList(v)),
      _load('/records/project', (v) => projects = aiList(v)),
      _load('/ai/gemini', (v) => gemini = aiObject(v)),
      _load('/ai-status', (v) => online = aiObject(v)['online'] == true),
    ]);
    if (!allowed) return;
    loading = false;
    changed();
  }

  Future<void> _load(String path, void Function(dynamic) assign) async {
    try {
      final data = await call(path);
      if (allowed) assign(data);
    } catch (e) {
      if (allowed) error = '$e';
    }
  }

  void newChat() {
    if (sending || !allowed) return;
    _selection++;
    _poll?.cancel();
    chat = null;
    run = null;
    pending = null;
    project = '';
    error = null;
    changed();
  }

  Future<void> open(String id) async {
    if (!allowed || sending) return;
    final selection = ++_selection;
    _poll?.cancel();
    run = null;
    error = null;
    try {
      final value = aiObject(
        await call('/ai/chats/${Uri.encodeComponent(id)}'),
      );
      if (!allowed || selection != _selection) return;
      chat = value;
      project = aiText(value['project']);
      pending = null;
      run = value['run'] is Map ? aiObject(value['run']) : null;
      _failures = 0;
      changed();
      _schedule();
    } catch (e) {
      if (allowed && selection == _selection) {
        error = '$e';
        changed();
      }
    }
  }

  String _requestId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<bool> send(String question, {AiObject? retry}) async {
    final text = question.trim();
    if (!allowed ||
        sending ||
        running ||
        text.isEmpty ||
        text.length > 4000 ||
        aiFlag(chat?['archived'])) {
      return false;
    }
    // A lost response is ambiguous: use the same server idempotency key, even
    // when the user presses Send again instead of the explicit Retry action.
    if (retry == null && pending != null) {
      if (pending!['question'] != text) {
        error = 'Retry your pending message or open a new conversation first.';
        changed();
        return false;
      }
      retry = pending;
    }
    final provider = aiText(retry?['provider']).isEmpty
        ? 'gideon'
        : aiText(retry?['provider']);
    final model = retry != null
        ? aiText(retry['model'])
        : collaborating
        ? aiText(gemini['model'])
        : '';
    if (model.isNotEmpty && (!collaborating || model != gemini['model'])) {
      error =
          'This reply used a different model connection. Restore that connection in Models before retrying.';
      changed();
      return false;
    }
    final selection = _selection;
    sending = true;
    error = null;
    changed();
    try {
      if (chat == null) {
        final created = aiObject(
          await call(
            '/ai/chats',
            body: {
              'title': text.length > 80 ? text.substring(0, 80) : text,
              'project': project,
            },
          ),
        );
        if (!allowed || selection != _selection) return false;
        chat = created;
      }
      if (!allowed || selection != _selection) return false;
      pending = {
        'question': text,
        'requestId':
            retry?['requestId'] ?? retry?['request_id'] ?? _requestId(),
        'provider': provider,
        'model': model,
        'cloudConsent': model.isNotEmpty && collaborating,
      };
      final value = aiObject(
        await call('/ai/chats/${chat!['id']}/runs', body: pending),
      );
      if (!allowed || selection != _selection) return false;
      run = value;
      try {
        await _readChat(selection);
      } catch (e) {
        if (allowed) error = '$e';
      }
      if (!allowed || selection != _selection) return false;
      _failures = 0;
      _schedule();
      return true;
    } catch (e) {
      if (allowed && selection == _selection) error = '$e';
      return false;
    } finally {
      if (allowed && selection == _selection) {
        sending = false;
        changed();
      }
    }
  }

  Future<void> _readChat(int selection) async {
    final id = chat?['id'];
    if (id == null) return;
    final value = aiObject(await call('/ai/chats/$id'));
    if (!allowed || selection != _selection) return;
    chat = value;
    run = value['run'] is Map ? aiObject(value['run']) : null;
    if (!running) pending = null;
    chats = [value, ...chats.where((c) => c['id'] != id)];
    changed();
  }

  void setVisible(bool visible) {
    _visible = visible;
    _poll?.cancel();
    if (visible) _schedule(immediate: true);
  }

  void _schedule({bool immediate = false}) {
    _poll?.cancel();
    if (!allowed || !_visible || !running) return;
    _poll = Timer(
      Duration(
        milliseconds: immediate
            ? 1
            : min(15000, 750 * (1 << min(_failures, 4))),
      ),
      _tick,
    );
  }

  Future<void> _tick() async {
    final selection = _selection;
    final id = run?['id'];
    if (!allowed || !_visible || id == null || _polling) return;
    _polling = true;
    try {
      final value = aiObject(await call('/ai/runs/$id'));
      if (!allowed || selection != _selection || run?['id'] != id) return;
      _failures = 0;
      error = null;
      if (!['queued', 'running'].contains(value['status'])) {
        await _readChat(selection);
        if (!allowed || selection != _selection) return;
        if (value['status'] != 'done') {
          error = aiText(value['error']).isEmpty
              ? 'The reply was interrupted. Retry your saved message.'
              : aiText(value['error']);
        }
      } else {
        run = value;
      }
      changed();
    } catch (e) {
      if (allowed && selection == _selection) {
        _failures++;
        error = '$e';
        changed();
      }
    } finally {
      _polling = false;
      _schedule();
    }
  }

  Future<void> editChat(AiObject body) async {
    final selection = _selection;
    final value = aiObject(await call('/ai/chats/${chat!['id']}', body: body));
    if (!allowed || selection != _selection) return;
    chat = {...chat!, ...value};
    chats = [chat!, ...chats.where((c) => c['id'] != value['id'])];
    changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _selection++;
    _poll?.cancel();
    state.removeListener(_accountChanged);
    super.dispose();
  }
}
