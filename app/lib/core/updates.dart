import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const appVersion = '1.1.0';
const appBuild = 8;
const updateOrigin = 'https://ryhze-updates.live-insights.workers.dev';
const updatePublicKey = 'gQ7hcr0OkoBlI/oTBDssW6sOswodVMdrtBPAqtatd+Q=';

class AppRelease {
  final String platform, version, path, sha256, notes;
  final int build, bytes;
  const AppRelease({
    required this.platform,
    required this.version,
    required this.build,
    required this.path,
    required this.sha256,
    required this.bytes,
    required this.notes,
  });
  String get filename => path.split('/').last;

  static Future<AppRelease?> verify(
    String envelope,
    String platform, {
    String publicKey = updatePublicKey,
  }) async {
    final data = jsonDecode(envelope) as Map<String, dynamic>;
    if (data['keyId'] != 'ryhze-updates-2026') {
      throw const FormatException('Unknown signing key');
    }
    final payload = base64Decode(data['payload'] as String);
    final signature = Signature(
      base64Decode(data['signature'] as String),
      publicKey: SimplePublicKey(
        base64Decode(publicKey),
        type: KeyPairType.ed25519,
      ),
    );
    if (!await Ed25519().verify(payload, signature: signature)) {
      throw const FormatException('Invalid update signature');
    }
    final manifest = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
    if (manifest['schema'] != 1) {
      throw const FormatException('Unknown update format');
    }
    final releases = (manifest['releases'] as List)
        .where((r) => r['platform'] == platform)
        .toList();
    if (releases.isEmpty) return null;
    if (releases.length != 1) throw const FormatException('Ambiguous release');
    final r = releases.single as Map<String, dynamic>;
    final version = r['version'] as String;
    final build = r['build'] as int;
    final bytes = r['bytes'] as int;
    final sha = r['sha256'] as String;
    final path = r['path'] as String;
    final notes = r['notes'] as String;
    final extension = platform == 'windows'
        ? 'Windows-Setup.exe'
        : 'Android.apk';
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
        build <= 0 ||
        bytes <= 0 ||
        bytes > 1024 * 1024 * 1024 ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha) ||
        notes.length > 4000 ||
        path != '/releases/$version/Ryhze-$version-$extension') {
      throw const FormatException('Invalid release information');
    }
    return AppRelease(
      platform: platform,
      version: version,
      build: build,
      path: path,
      sha256: sha,
      bytes: bytes,
      notes: notes,
    );
  }
}

enum UpdatePhase {
  idle,
  checking,
  current,
  available,
  downloading,
  ready,
  installing,
  failed,
}

class AppUpdates extends ChangeNotifier {
  final String platform;
  final int currentBuild;
  final String publicKey;
  final http.Client Function() clientFactory;
  final Future<Directory> Function() directory;
  final Future<String?> Function(File, AppRelease) installer;
  UpdatePhase phase = UpdatePhase.idle;
  AppRelease? release;
  String? error, instruction;
  double progress = 0;
  bool dismissed = false;
  DateTime? checkedAt;
  Timer? _timer;
  http.Client? _client;
  bool _disposed = false;
  bool _downloadActive = false;
  int _operation = 0;

  AppUpdates({
    String? platform,
    this.currentBuild = appBuild,
    this.publicKey = updatePublicKey,
    http.Client Function()? clientFactory,
    Future<Directory> Function()? directory,
    Future<String?> Function(File, AppRelease)? installer,
  }) : platform = platform ?? Platform.operatingSystem,
       clientFactory = clientFactory ?? http.Client.new,
       directory = directory ?? _updateDirectory,
       installer = installer ?? _install;

  bool get supported => platform == 'windows' || platform == 'android';
  bool get busy =>
      _downloadActive ||
      [
        UpdatePhase.checking,
        UpdatePhase.downloading,
        UpdatePhase.installing,
      ].contains(phase);
  bool get available => release != null && release!.build > currentBuild;
  bool get showBanner => available && !dismissed;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void start() {
    if (!supported || _timer != null) return;
    unawaited(check());
    _timer = Timer.periodic(const Duration(hours: 6), (_) => check());
  }

  void resume() {
    if (checkedAt == null ||
        DateTime.now().difference(checkedAt!) >= const Duration(hours: 6)) {
      unawaited(check());
    }
  }

  void dismiss() {
    dismissed = true;
    _notify();
  }

  Future<void> check() async {
    if (!supported || busy || _disposed) return;
    final operation = ++_operation;
    final previousPhase = phase;
    phase = UpdatePhase.checking;
    error = null;
    _notify();
    final client = clientFactory();
    _client = client;
    try {
      final response = await client
          .send(
            http.Request('GET', Uri.parse('$updateOrigin/stable.json'))
              ..followRedirects = false,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const HttpException('Update service unavailable');
      }
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 15),
      )) {
        bytes.addAll(chunk);
        if (bytes.length > 32768) {
          throw const FormatException('Update index too large');
        }
      }
      final latest = await AppRelease.verify(
        utf8.decode(bytes),
        platform,
        publicKey: publicKey,
      );
      if (_disposed || operation != _operation) return;
      checkedAt = DateTime.now();
      // Build numbers are monotonic; never offer an older or the installed build.
      if (latest == null || latest.build <= currentBuild) {
        release = null;
        phase = UpdatePhase.current;
      } else {
        if (release?.build != latest.build) dismissed = false;
        release = latest;
        phase = UpdatePhase.available;
        final file = File('${(await directory()).path}/${latest.filename}');
        if (await _verified(file, latest)) phase = UpdatePhase.ready;
      }
    } catch (_) {
      if (_disposed || operation != _operation) return;
      phase = previousPhase == UpdatePhase.ready
          ? UpdatePhase.ready
          : UpdatePhase.failed;
      error =
          'Could not check for updates. Check your internet connection and try again.';
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
      _notify();
    }
  }

  Future<void> download() async {
    if (!available || busy || _disposed) return;
    final target = release!;
    _downloadActive = true;
    final operation = ++_operation;
    phase = UpdatePhase.downloading;
    error = null;
    instruction = null;
    progress = 0;
    _notify();
    final client = clientFactory();
    _client = client;
    File? partial;
    IOSink? sink;
    try {
      final folder = await directory();
      await folder.create(recursive: true);
      final file = File('${folder.path}/${target.filename}');
      if (await _verified(file, target)) {
        phase = UpdatePhase.ready;
        return;
      }
      partial = File('${file.path}.part');
      final response = await client
          .send(
            http.Request('GET', Uri.parse('$updateOrigin${target.path}'))
              ..followRedirects = false,
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 ||
          (response.contentLength != null &&
              response.contentLength != target.bytes)) {
        throw const HttpException('Package unavailable');
      }
      sink = partial.openWrite();
      var received = 0;
      var lastReport = DateTime.now();
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        if (_disposed || operation != _operation) {
          throw const HttpException('Cancelled');
        }
        received += chunk.length;
        if (received > target.bytes) {
          throw const FormatException('Package too large');
        }
        sink.add(chunk);
        // Flush for backpressure rather than buffering a whole installer in memory.
        await sink.flush();
        progress = received / target.bytes;
        if (DateTime.now().difference(lastReport).inMilliseconds > 100) {
          _notify();
          lastReport = DateTime.now();
        }
      }
      await sink.close();
      sink = null;
      if (!await _verified(partial, target)) {
        throw const FormatException('Package verification failed');
      }
      if (_disposed || operation != _operation) return;
      if (await file.exists()) await file.delete();
      await partial.rename(file.path);
      phase = UpdatePhase.ready;
      progress = 1;
    } catch (_) {
      if (!_disposed && operation == _operation) {
        phase = UpdatePhase.failed;
        error =
            'The update could not be downloaded and verified. Please try again.';
      }
    } finally {
      try {
        await sink?.close();
        if (partial != null && await partial.exists()) await partial.delete();
      } on FileSystemException {
        // A full or unavailable disk must not leave the updater busy or crash
        // the app. A subsequent download truncates any remaining .part file.
      }
      client.close();
      if (identical(_client, client)) _client = null;
      _downloadActive = false;
      _notify();
    }
  }

  void cancelDownload() {
    if (phase != UpdatePhase.downloading) return;
    ++_operation;
    _client?.close();
    phase = UpdatePhase.available;
    progress = 0;
    _notify();
  }

  Future<void> install() async {
    if (phase != UpdatePhase.ready || release == null || _disposed) return;
    phase = UpdatePhase.installing;
    error = null;
    instruction = null;
    _notify();
    try {
      final file = File('${(await directory()).path}/${release!.filename}');
      if (!await _verified(file, release!)) {
        phase = UpdatePhase.available;
        throw const FormatException('Downloaded package changed');
      }
      instruction = await installer(file, release!);
      phase = UpdatePhase.ready;
    } catch (failure) {
      assert(() {
        debugPrint('Ryhze update handoff: $failure');
        return true;
      }());
      if (phase == UpdatePhase.installing) phase = UpdatePhase.ready;
      error = 'Installation could not start. Please try again.';
    }
    _notify();
  }

  static Future<bool> _verified(File file, AppRelease release) async =>
      await file.exists() &&
      await file.length() == release.bytes &&
      (await hashes.sha256.bind(file.openRead()).first).toString() ==
          release.sha256;

  static Future<Directory> _updateDirectory() async =>
      Directory('${(await getTemporaryDirectory()).path}/ryhze-updates');

  static Future<String?> _install(File file, AppRelease release) async {
    if (Platform.isAndroid) {
      final result = await const MethodChannel(
        'com.ryhze.ryhze/updates',
      ).invokeMethod<String>('install', {'path': file.path});
      return result == 'permission'
          ? 'Allow updates from Ryhze in Android settings, then return and tap Install update.'
          : 'Confirm the update in the Android installation screen.';
    }
    if (Platform.isWindows) {
      final script = File('${file.parent.path}/update-windows.ps1');
      await script.writeAsString(
        await rootBundle.loadString('assets/update/update-windows.ps1'),
        flush: true,
      );
      final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
      final ready = File(
        '${file.parent.path}/handoff-$pid-${DateTime.now().microsecondsSinceEpoch}.txt',
      );
      final helper = await Process.start(
        '$systemRoot/System32/WindowsPowerShell/v1.0/powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-WindowStyle',
          'Hidden',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          script.path,
          '-Installer',
          file.path,
          '-InstallDir',
          File(Platform.resolvedExecutable).parent.path,
          '-AppProcessId',
          '$pid',
          '-ExpectedHash',
          release.sha256,
          '-ExpectedVersion',
          '${release.version}+${release.build}',
          '-ReadyFile',
          ready.path,
        ],
        // Windows PowerShell needs valid standard handles to initialize. A
        // hidden normal child survives our explicit exit after the handshake.
        mode: ProcessStartMode.normal,
      );
      unawaited(helper.stdout.drain<void>());
      unawaited(helper.stderr.drain<void>());
      unawaited(helper.stdin.close());
      // Keep the application alive until the helper has started and independently
      // verified the package. A failed launch must leave a usable app on screen.
      try {
        for (var attempt = 0; attempt < 150; attempt++) {
          if (await ready.exists()) {
            if (await ready.readAsString() == 'ready') {
              await ready.delete();
              exit(0);
            }
            throw const FileSystemException('Update helper could not start');
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        throw const FileSystemException('Update helper did not respond');
      } finally {
        if (await ready.exists()) await ready.delete();
      }
    }
    throw UnsupportedError('Updates are unavailable on this platform');
  }

  @override
  void dispose() {
    _disposed = true;
    ++_operation;
    _timer?.cancel();
    _client?.close();
    super.dispose();
  }
}
