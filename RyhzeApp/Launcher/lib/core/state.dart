import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'agreement.dart';
import 'api.dart';
import 'models.dart';
import 'library_sync.dart';

class RyhzeState extends ChangeNotifier {
  final RyhzeApi api;
  final SharedPreferences prefs;
  final bool featuredMotion;
  Member? user;
  List<RyhzeTitle> titles = [];

  /// The agreement in force that this account has not yet accepted on this
  /// device. The shell shows it and nothing else proceeds until it is agreed
  /// to or the person signs out. Null while the website is still serving
  /// drafts (503), on an older website (404), or once accepted.
  Agreement? pendingAgreement;
  late final AgreementRecords agreements = AgreementRecords(prefs);
  bool loading = true;
  String? error, notice;
  int _sequence = 0;
  Timer? _catalogueTimer;
  int? _catalogueRevision;
  bool catalogueUpdateAvailable = false;
  Future<void> checkCatalogueUpdate() async {
    try {
      final data = await api.request('/api/catalog/revision');
      final revision = data['revision'] as int;
      if (_catalogueRevision == null) {
        _catalogueRevision = revision;
      } else if (_catalogueRevision != revision) {
        catalogueUpdateAvailable = true;
        notifyListeners();
      }
    } catch (_) {
      /* Retain the current catalogue while offline. */
    }
  }

  Future<void> applyCatalogueUpdate() async {
    await refresh();
    if (error == null) {
      _catalogueRevision = null;
      catalogueUpdateAvailable = false;
      await checkCatalogueUpdate();
      notifyListeners();
    }
  }

  late final LibrarySync library;
  RyhzeState(
    this.api,
    this.prefs, {
    bool libraryAutoSync = true,
    this.featuredMotion = true,
  }) {
    library = LibrarySync(api, prefs, autoSync: libraryAutoSync)
      ..addListener(libraryChanged);
    if (libraryAutoSync) {
      _catalogueTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => checkCatalogueUpdate(),
      );
    }
  }
  void libraryChanged() {
    if (library.sessionExpired) {
      _sequence++;
      user = null;
      titles = titles.where((t) => !t.internal).toList();
    }
    notifyListeners();
  }

  bool get adminAccess =>
      user?.role == 'admin' && (prefs.getBool('admin-view:$scope') ?? false);
  int engineCatalogueRevision = 0;
  void engineCatalogueChanged() {
    engineCatalogueRevision++;
    notifyListeners();
  }

  String? _engineArtworkScope;
  Map<String, dynamic>? _engineThumbnail;
  Map<String, dynamic>? get engineThumbnail =>
      engineAccess && _engineArtworkScope == scope ? _engineThumbnail : null;
  void setEngineThumbnail(Object? value) {
    _engineArtworkScope = scope;
    _engineThumbnail = value is Map ? Map<String, dynamic>.from(value) : null;
    notifyListeners();
  }

  Future<void> refreshEngineThumbnail() async {
    if (!engineAccess) return;
    final account = scope;
    try {
      final catalogue = await api.request('/api/engine/releases');
      if (engineAccess && scope == account) {
        setEngineThumbnail(catalogue['thumbnail']);
      }
    } catch (_) {
      /* Keep the last usable artwork while offline. */
    }
  }

  bool get engineAccess =>
      user?.role == 'admin' ? adminAccess : user?.developerAccess == true;
  bool get engineDownloadAccess =>
      engineAccess &&
      (user?.role == 'admin' || user?.engineDownloadAccess == true);

  Future<void> authorizeEngineInstall() async {
    final original = user;
    if (original == null || !engineAccess) {
      throw const ApiException('Sign in with an authorised RACE account.');
    }
    final result = await api.request('/api/session');
    final fresh = Member.fromJson(result['user']);
    if (user?.username != original.username ||
        fresh.username != original.username ||
        fresh.role != original.role) {
      throw const ApiException(
        'Your account changed. Refresh before installing.',
      );
    }
    user = fresh;
    notifyListeners();
    if (!engineDownloadAccess) {
      throw const ApiException(
        'Engine downloads are paused. Ask an administrator to allow engine access.',
        403,
      );
    }
  }

  bool get portalAccess =>
      user?.portalAccess == true && (user?.role != 'admin' || adminAccess);
  List<RyhzeTitle> get visibleTitles => user?.role == 'admin' && !adminAccess
      ? titles.where((title) => !title.internal).toList()
      : titles;
  bool get publishingAccess => adminAccess && user?.launcherAdmin == true;
  Future<void> setAdminAccess(bool enabled) async {
    if (user?.role != 'admin') return;
    final saved = prefs.setBool('admin-view:$scope', enabled);
    notifyListeners();
    if (!await saved) {
      throw const ApiException('Your preference could not be saved.');
    }
  }

  bool get reduced => prefs.getBool('reduced-motion') ?? false;
  bool get sound => prefs.getBool('ambient-sound') ?? true;
  String get scope => user?.username ?? 'guest';
  Set<String> get saved => user == null
      ? {}
      : library.account == scope
      ? library.entries.entries
            .where(
              (e) => e.key.startsWith('favorite:') && e.value['value'] == true,
            )
            .map((e) => e.key.substring(9))
            .toSet()
      : (prefs.getStringList('saved:$scope') ?? []).toSet();
  Set<String> get alerts =>
      (prefs.getStringList('alerts:$scope') ?? []).toSet();
  Map<String, dynamic> get history {
    if (user == null) return {};
    if (library.account == scope) {
      return {
        for (final e in library.entries.entries)
          if (e.key.startsWith('progress:') && e.value['value'] != null)
            e.key.substring(9): e.value['value'],
      };
    }
    try {
      return jsonDecode(prefs.getString('history:$scope') ?? '{}');
    } catch (_) {
      return {};
    }
  }

  Future<void> initialize() async {
    await api.connect();
    try {
      await api.restore();
    } catch (_) {
      error = 'Secure storage is unavailable. Sign in again to continue.';
    }
    await refresh();
    await checkCatalogueUpdate();
  }

  Future<void> refresh() async {
    final sequence = ++_sequence;
    loading = true;
    error = null;
    notifyListeners();
    try {
      Member? member;
      try {
        final data = await api.request('/api/session');
        member = Member.fromJson(data['user']);
      } on ApiException catch (e) {
        if (e.status != 401) rethrow;
      }
      if (sequence != _sequence) return;
      user = member;
      await loadAgreement();
      if (sequence != _sequence) return;
      await library.attach(member?.username);
      // Never retain a previous account's protected catalogue after expiry.
      titles = titles.where((t) => !t.internal).toList();
      final data = await api.request(
        member == null ? '/api/discover' : '/api/catalog',
      );
      if (sequence != _sequence) return;
      titles = (data as List).map((t) => RyhzeTitle.fromJson(t)).toList();
      final released = titles
          .where((t) => alerts.contains(t.id) && t.availability == 'available')
          .toList();
      if (released.isNotEmpty) {
        notice =
            '${released.map((t) => t.title).join(', ')} is now available on Ryhze.';
        await prefs.setStringList(
          'alerts:$scope',
          alerts.difference(released.map((t) => t.id).toSet()).toList(),
        );
      }
    } catch (e) {
      if (sequence != _sequence) return;
      error = e is ApiException
          ? e.message
          : 'Unable to load Ryhze. Please try again.';
      if (titles.isEmpty) {
        final data =
            jsonDecode(await rootBundle.loadString('assets/catalog.json'))
                as List;
        titles = data.map((t) => RyhzeTitle.fromJson(t)).toList();
      }
    } finally {
      if (sequence == _sequence) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadAgreement() async {
    final member = user;
    if (member == null) {
      pendingAgreement = null;
      return;
    }
    try {
      final data = await api.request('/api/legal/agreement?product=app');
      final agreement = Agreement.parse(data);
      pendingAgreement = agreement != null && !agreements.accepted(scope, agreement)
          ? agreement
          : null;
    } on ApiException catch (e) {
      // 503: the documents are still drafts. 404: an older website. Either
      // way there is nothing in force to present. Any other failure keeps
      // whatever was already pending rather than inventing a gate offline.
      if (e.status == 503 || e.status == 404) pendingAgreement = null;
    } catch (_) {
      /* Offline: keep the current state. */
    }
  }

  Future<void> acceptAgreement() async {
    final agreement = pendingAgreement;
    if (agreement == null) return;
    await agreements.record(scope, agreement);
    pendingAgreement = null;
    notifyListeners();
    try {
      await api.request(
        '/api/legal/accept',
        body: {'key': agreement.key, 'sha256': agreement.digest, 'channel': 'app'},
      );
    } catch (_) {
      /* The device record is the acceptance of record; the server copy is best effort. */
    }
  }

  Future<void> declineAgreement() async {
    pendingAgreement = null;
    try {
      await logout();
    } catch (_) {
      // The local session is already gone; the server copy can expire.
      notifyListeners();
    }
  }

  Future<void> login(String username, String password, bool remember) async {
    final data = await api.request(
      '/api/login',
      body: {
        'username': username.trim(),
        'password': password,
        'remember': remember,
      },
      remember: remember,
    );
    user = Member.fromJson(data['user']);
    titles = [];
    await refresh();
    if (user == null) {
      throw const ApiException(
        'Your session could not be confirmed. Please sign in again.',
      );
    }
  }

  Future<void> websiteLogin() async {
    await api.websiteSignIn();
    titles = [];
    await refresh();
    if (user == null) {
      throw const ApiException(
        'Your website session could not be confirmed. Please sign in again.',
      );
    }
  }

  Future<void> logout() async {
    user = null;
    pendingAgreement = null;
    titles = [];
    await library.attach(null);
    notifyListeners();
    await api.logout();
    await refresh();
  }

  Future<void> toggleSaved(RyhzeTitle title) async {
    if (user == null) {
      throw const ApiException(
        'Sign in to keep your favourites in Favourites.',
      );
    }
    await library.attach(user!.username);
    await library.change(
      'favorite:${title.id}',
      saved.contains(title.id) ? null : true,
    );
  }

  Future<void> toggleAlert(RyhzeTitle title) async {
    final next = alerts;
    next.contains(title.id) ? next.remove(title.id) : next.add(title.id);
    if (!await prefs.setStringList('alerts:$scope', next.toList())) {
      throw const ApiException('Your notification could not be saved.');
    }
    notifyListeners();
  }

  Future<void> preference(String key, bool value) async {
    if (!await prefs.setBool(key, value)) {
      throw const ApiException('Your preference could not be saved.');
    }
    notifyListeners();
  }

  Future<void> progress(
    String id,
    String stream,
    Duration position,
    Duration duration,
  ) async {
    if (user == null || duration.inSeconds == 0) return;
    await library.attach(user!.username);
    await library.change('progress:$id', {
      'stream': stream,
      'position': position.inSeconds,
      'duration': duration.inSeconds,
      'updated': DateTime.now().toIso8601String(),
      'watched': position.inMilliseconds / duration.inMilliseconds >= .95,
    });
  }

  Future<void> clearHistory() async {
    for (final id in history.keys.toList()) {
      await library.change('progress:$id', null);
    }
    await prefs.remove('history:$scope');
    notifyListeners();
  }

  @override
  void dispose() {
    _catalogueTimer?.cancel();
    library.removeListener(libraryChanged);
    library.dispose();
    super.dispose();
  }
}
