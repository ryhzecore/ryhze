import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../core/state.dart';
import '../core/engine_licence.dart';
import '../core/race_installation.dart';
import 'engine_licence.dart';
import 'design.dart';
import 'option_menu.dart';
import 'engine_demo.dart';
import 'engine_editor.dart';
import 'engine_gallery.dart';

Future<String> canonicalEngineExecutable(String executable) async {
  var resolved = executable;
  try {
    resolved = await File(executable).resolveSymbolicLinks();
  } on FileSystemException {
    // Discovery may use a different spelling of an existing Windows path.
  }
  resolved = resolved.replaceAll('/', r'\');
  if (resolved.toLowerCase().startsWith(r'\\?\unc\')) {
    resolved = r'\\' + resolved.substring(8);
  } else if (resolved.startsWith(r'\\?\')) {
    resolved = resolved.substring(4);
  }
  return path.windows.normalize(resolved).toLowerCase();
}

Future<String?> managedEngineForExecutable(
  String executable,
  Map<String, dynamic> installations,
) async {
  if (installations.isEmpty) return null;
  final canonical = await canonicalEngineExecutable(executable);
  for (final entry in installations.entries) {
    final candidate = entry.value['executable'];
    if (candidate is String &&
        await canonicalEngineExecutable(candidate) == canonical) {
      return entry.key;
    }
  }
  // A reported version or an unverified manifest is not a build identity.
  return null;
}

String localEngineVersionDescription(String? detectedVersion) {
  final version = RegExp(
    r'\d+\.\d+\.\d+',
  ).firstMatch(detectedVersion ?? '')?.group(0);
  return version == null
      ? 'Executable version unknown. This local installation is not a verified release.'
      : 'Executable reports $version. This local installation is not a verified release.';
}

class EngineBuild {
  String get displayLabel {
    const titles = {
      '0.0.8': 'Game Export',
      '0.0.7': 'Source Backup',
      '0.0.6': 'Project Presets',
      '0.0.5': 'Scripted Sandbox',
      '0.0.4': 'Rotation Fixes',
    };
    const revisions = {
      'RACE-0.0.3-Windows-20260912-201847-989': 'GLB Import',
      'RACE-0.0.3-Windows-20260912-185827-636': 'Live DXR Workspace',
      'RACE-0.0.3-Windows-20260912-183134-906': 'DXR Snapshots',
      'RACE-0.0.3-Windows-20260912-181213-927': 'Transform Tools',
    };
    return 'V$displayVersion - ${title.isNotEmpty ? title : revisions[id] ?? titles[version] ?? 'Development Build'}';
  }

  final String id, version, url, sha, entrypoint, notes;
  final String displayVersion, title;
  final List<Map<String, dynamic>> media;
  final int? buildNumber;
  final int bytes;
  final EngineDemo? demo;

  /// The release's own licence text, served only to accounts allowed to
  /// download. Verified against its hash; the server refuses the download
  /// unless that same hash is sent back as proof it was accepted.
  final EngineLicence? agreement;
  EngineBuild.fromJson(Map<String, dynamic> j)
    : title = j['title'] as String? ?? '',
      agreement = EngineLicence.parse(j['agreement']),
      media = (j['media'] as List? ?? [])
          .map((m) => Map<String, dynamic>.from(m))
          .toList(),
      id = j['id'],
      version = j['version'],
      buildNumber = j['buildNumber'] as int?,
      displayVersion = j['displayVersion'] as String? ?? j['version'],
      url = j['url'],
      sha = j['sha256'],
      entrypoint = j['entrypoint'],
      notes = j['notes'] ?? '',
      demo = EngineDemo.parse(j['demo'], j['id']),
      bytes = j['bytes'] {
    if (title.length > 160 ||
        media.length > 20 ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,120}$').hasMatch(id) ||
        !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
        (buildNumber != null && (buildNumber! < 1 || buildNumber! > 1000000)) ||
        displayVersion !=
            (buildNumber == null ? version : '$version Build $buildNumber') ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha) ||
        bytes <= 0 ||
        bytes > 2 * 1024 * 1024 * 1024 ||
        url != '/api/engine/releases/$id/download' ||
        entrypoint != '$id/RACE.exe') {
      throw const FormatException('Invalid RACE build metadata.');
    }
    if (j['agreement'] != null && agreement == null) {
      throw const FormatException('Invalid RACE release agreement.');
    }
    for (final item in media) {
      final mediaId = item['id'];
      if (mediaId is! String ||
          !RegExp(
            r'^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$',
          ).hasMatch(mediaId) ||
          item['url'] != '/api/engine/releases/media/$mediaId' ||
          ![
            'image/png',
            'image/jpeg',
            'image/webp',
            'video/mp4',
          ].contains(item['mime']) ||
          item['title'] is! String ||
          (item['title'] as String).length > 200 ||
          item['bytes'] is! int ||
          (item['bytes'] as int) <= 0 ||
          item['sha256'] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(item['sha256'])) {
        throw const FormatException('Invalid RACE version media.');
      }
    }
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'buildNumber': ?buildNumber,
    if (displayVersion != version) 'displayVersion': displayVersion,
    'url': url,
    'sha256': sha,
    'bytes': bytes,
    'entrypoint': entrypoint,
    'notes': notes,
    'title': title,
    'media': media,
    if (demo != null) 'demo': demo!.toJson(),
    // The text itself is never persisted with an installation; its hash is
    // enough to tell which agreement that install was made under.
    if (agreement != null) 'agreementSha256': agreement!.digest,
  };
}

class EngineVersions extends StatefulWidget {
  final RyhzeState state;
  final double? horizontalPadding;
  final bool embedded;
  final String? uninstallRequested;
  final Widget Function(EngineBuild?)? artworkBuilder;
  const EngineVersions({
    super.key,
    required this.state,
    this.horizontalPadding,
    this.embedded = false,
    this.uninstallRequested,
    this.artworkBuilder,
  });
  @override
  State<EngineVersions> createState() => _EngineVersionsState();
}

class _EngineVersionsState extends State<EngineVersions> {
  static const installsKey = 'race-managed-installations';
  List<EngineBuild> releases = [];
  Set<String> unsupported = {};
  bool removalStarted = false;
  Map<String, dynamic> installs = {};
  String? selected, locatedExecutable, locatedVersion, message;
  bool busy = false, downloading = false, installing = false;
  bool uninstalling = false;
  bool downloaded = false;
  double progress = 0;
  int generation = 0;
  http.Client? client;
  RyhzeState get state => widget.state;
  bool get allowed => state.engineAccess;
  @override
  void initState() {
    super.initState();
    selected = widget.uninstallRequested;
    state.addListener(accountChanged);
    unawaited(refresh());
  }

  void accountChanged() {
    if (!allowed) cancel();
  }

  @override
  void dispose() {
    generation++;
    client?.close();
    state.removeListener(accountChanged);
    super.dispose();
  }

  void cancel() {
    if (uninstalling) return;
    generation++;
    client?.close();
    client = null;
    if (mounted) {
      setState(() {
        busy = false;
        downloading = false;
        downloaded = false;
        installing = false;
        message = 'Download cancelled.';
      });
    }
  }

  Future<String?> reconcileLocated(Map<String, dynamic>? located) async {
    final managed = located == null
        ? null
        : await managedEngineForExecutable(located['executable'], installs);
    locatedExecutable = null;
    locatedVersion = null;
    if (managed == null && located != null) {
      locatedExecutable = located['executable'];
      locatedVersion = located['version'];
    }
    if (selected == 'located' && locatedExecutable == null) {
      selected =
          managed ?? installs.keys.firstOrNull ?? releases.firstOrNull?.id;
      if (selected == null) {
        await state.prefs.remove('race-selected-build');
      } else {
        await state.prefs.setString('race-selected-build', selected!);
      }
    }
    return managed;
  }

  Future<void> refresh() async {
    if (!allowed || busy) return;
    final epoch = ++generation;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      try {
        installs = Map<String, dynamic>.from(
          jsonDecode(state.prefs.getString(installsKey) ?? '{}'),
        );
      } catch (_) {
        installs = {};
      }
      for (final id in installs.keys.toList()) {
        try {
          final entry = Map<String, dynamic>.from(installs[id]);
          final build = EngineBuild.fromJson(
            Map<String, dynamic>.from(entry['release']),
          );
          if (build.id != id || !await File(entry['executable']).exists()) {
            installs.remove(id);
          }
        } catch (_) {
          installs.remove(id);
        }
      }
      final current =
          state.prefs.getString('race-located-directory') ??
          state.prefs.getString(raceDirectoryKey);
      final located = await raceInstallation(directory: current);
      if (!mounted || epoch != generation || !allowed) return;
      selected ??= state.prefs.getString('race-selected-build');
      final managed = await reconcileLocated(located);
      if (!mounted || epoch != generation || !allowed) return;
      if (located != null) {
        await state.prefs.setString('race-located-directory', located['path']);
      }
      selected ??= managed ?? (locatedExecutable != null ? 'located' : null);
      if (!mounted || epoch != generation || !allowed) return;
      setState(() {});
      final result = await state.api.request('/api/engine/releases');
      if (!mounted || epoch != generation || !allowed) return;
      if (result['schema'] != 1) {
        throw const FormatException('Unsupported RACE catalogue.');
      }
      state.setEngineThumbnail(result['thumbnail']);
      unsupported = Set<String>.from(result['unsupported'] ?? []);
      releases = (result['releases'] as List)
          .map((r) => EngineBuild.fromJson(Map<String, dynamic>.from(r)))
          .toList();
      // Published catalogue order defines latest, including version renumbering.
      selected ??= state.prefs.getString('race-selected-build');
      final choices = {
        ...releases.map((r) => r.id),
        ...installs.keys,
        if (locatedExecutable != null) 'located',
      };
      if (!choices.contains(selected)) {
        selected = locatedExecutable != null
            ? 'located'
            : releases.firstOrNull?.id;
      }
    } catch (e) {
      if (mounted && epoch == generation) message = '$e';
    } finally {
      if (mounted && epoch == generation) {
        setState(() => busy = false);
        final requested = widget.uninstallRequested;
        if (!removalStarted &&
            requested != null &&
            selected == requested &&
            unsupported.contains(requested) &&
            installs.containsKey(requested)) {
          removalStarted = true;
          final release = EngineBuild.fromJson(
            Map<String, dynamic>.from(installs[requested]['release']),
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && allowed) {
              unawaited(uninstall(release, confirmedByUser: true));
            }
          });
        }
      }
    }
  }

  String? get executable => selected == 'located'
      ? locatedExecutable
      : installs[selected]?['executable'];
  Future<void> select(String id) async {
    if (busy) return;
    setState(() {
      selected = id;
      message = null;
    });
    await state.prefs.setString('race-selected-build', id);
    final exe = executable;
    if (exe != null) {
      await state.prefs.setString(raceDirectoryKey, File(exe).parent.path);
    }
  }

  /// Acceptance of a release's licence on this device: account, release,
  /// package hash, agreement hash and time, as RACE-LICENCE-CONTRACT.md
  /// specifies. No project content, hardware or network identifiers.
  static const raceAgreementsKey = 'race-agreements';
  Map<String, dynamic> _raceAgreements() {
    try {
      final raw = state.prefs.getString(raceAgreementsKey);
      return raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return {};
    }
  }

  Future<void> recordRaceAgreement(EngineBuild build) async {
    final records = _raceAgreements()
      ..['${state.scope}:${build.id}'] = {
        'account': state.scope,
        'releaseId': build.id,
        'packageSha256': build.sha,
        'agreementSha256': build.agreement!.digest,
        'acceptedAt': DateTime.now().toUtc().toIso8601String(),
      };
    await state.prefs.setString(raceAgreementsKey, jsonEncode(records));
  }

  Future<void> install(EngineBuild build) async {
    if (!allowed || busy || !Platform.isWindows) return;
    final epoch = ++generation;
    setState(() {
      busy = true;
      downloading = false;
      progress = 0;
      message = null;
    });
    Directory? temporary;
    http.Client? ownedClient;
    try {
      await state.authorizeEngineInstall();
      if (!mounted || epoch != generation || !allowed) return;
      final fresh = await state.api.request('/api/engine/releases');
      final verified = (fresh['releases'] as List)
          .map((r) => EngineBuild.fromJson(Map<String, dynamic>.from(r)))
          .where((r) => r.id == build.id)
          .firstOrNull;
      if (verified == null || verified.sha != build.sha) {
        throw StateError('This release changed. Refresh the version list.');
      }
      if (!mounted || epoch != generation || !allowed) return;
      final agreement = verified.agreement;
      // Shown on every download, even a repeat of the same release: the
      // person reads and agrees each time they take the engine.
      if (agreement != null) {
        final agreed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => EngineLicenceDialog(
            releaseId: verified.id,
            version: verified.displayVersion,
            licence: agreement,
            authorization: state,
            canInstall: () => allowed,
          ),
        );
        if (!mounted || epoch != generation || !allowed) return;
        if (agreed != true) {
          throw StateError(
            'The licence must be accepted to install RACE ${verified.displayVersion}.',
          );
        }
        await recordRaceAgreement(verified);
      }
      setState(() => downloading = true);
      final support = await getApplicationSupportDirectory();
      final root = Directory('${support.path}/RACE/versions');
      await root.create(recursive: true);
      final destination = Directory('${root.path}/${build.id}');
      if (await destination.exists()) {
        throw StateError(
          'This build already has an installation folder. Use Locate RACE to inspect it; existing files are never overwritten.',
        );
      }
      temporary = await (await getTemporaryDirectory()).createTemp(
        'ryhze-race-',
      );
      final zip = File('${temporary.path}/package.zip');
      final activeClient = ownedClient = client = http.Client();
      final req = http.Request('GET', state.api.resource(build.url))
        ..followRedirects = false
        ..headers.addAll({
          ...state.api.authHeaders,
          if (agreement != null) 'X-RACE-Agreement-SHA256': agreement.digest,
        });
      final response = await activeClient
          .send(req)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw StateError(
          'RACE download requires an active authorised sign-in.',
        );
      }
      final sink = zip.openWrite();
      int bytes = 0;
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 45),
        )) {
          if (epoch != generation || !allowed) {
            throw StateError('Download cancelled.');
          }
          bytes += chunk.length;
          if (bytes > build.bytes) throw StateError('Invalid package size.');
          sink.add(chunk);
          if (mounted) setState(() => progress = bytes / build.bytes);
        }
      } finally {
        await sink.close();
      }
      if (bytes != build.bytes) {
        throw StateError('RACE package verification failed.');
      }
      if (!mounted || epoch != generation || !allowed) return;
      setState(() {
        progress = 1;
        downloading = false;
        downloaded = true;
      });
      await WidgetsBinding.instance.endOfFrame;
      if ((await sha256.bind(zip.openRead()).first).toString() != build.sha) {
        throw StateError('RACE package verification failed.');
      }
      if (!mounted || epoch != generation || !allowed) return;
      await state.authorizeEngineInstall();
      if (!mounted || epoch != generation || !allowed) return;
      setState(() {
        downloading = false;
        installing = true;
      });
      final script = File('${temporary.path}/install.ps1');
      await script.writeAsString(
        await rootBundle.loadString('assets/update/install-race-version.ps1'),
      );
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        script.path,
        '-Archive',
        zip.path,
        '-Root',
        root.path,
        '-BuildId',
        build.id,
        '-Entrypoint',
        build.entrypoint,
        '-Sha256',
        build.sha,
      ]);
      if (result.exitCode != 0) {
        throw StateError(
          'RACE installation did not complete. Existing versions were preserved. ${result.stderr}',
        );
      }
      final exe = File('${destination.path}/${build.entrypoint}');
      if (!await exe.exists()) {
        throw StateError('Installed executable is missing.');
      }
      final manifestHash =
          (await sha256
                  .bind(
                    File('${exe.parent.path}/package-manifest.json').openRead(),
                  )
                  .first)
              .toString();
      installs[build.id] = {
        'executable': exe.path,
        'release': build.toJson(),
        'manifestSha256': manifestHash,
      };
      if (!await state.prefs.setString(installsKey, jsonEncode(installs))) {
        throw StateError(
          'Installed build could not be registered. Use Locate RACE.',
        );
      }
      await reconcileLocated(
        locatedExecutable == null
            ? null
            : {'executable': locatedExecutable, 'version': locatedVersion},
      );
      if (selected == build.id && epoch == generation && allowed) {
        await state.prefs.setString(raceDirectoryKey, exe.parent.path);
        await state.prefs.setString('race-selected-build', build.id);
      }
      message =
          'RACE ${build.displayVersion} is installed. Other versions were kept.';
    } catch (e) {
      if (mounted && epoch == generation) message = '$e';
    } finally {
      ownedClient?.close();
      if (identical(client, ownedClient)) client = null;
      if (temporary != null && await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
      if (mounted && epoch == generation) {
        setState(() {
          busy = false;
          downloading = false;
          downloaded = false;
          installing = false;
        });
      }
    }
  }

  Future<void> launch() async {
    if (unsupported.contains(selected)) {
      throw StateError('Old version is no longer supported');
    }
    if (!allowed || busy || executable == null) return;
    final exe = File(
      executable!,
    ).absolute.path.replaceAll('/', Platform.pathSeparator);
    setState(() => busy = true);
    try {
      if (!mounted || !allowed) return;
      if (!await File(exe).exists()) {
        throw StateError(
          'This installation is missing. Locate RACE or install a verified build.',
        );
      }
      final running = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'if(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $env:RYHZE_SELECTED_EXE }) { exit 10 }',
        ],
        environment: {...Platform.environment, 'RYHZE_SELECTED_EXE': exe},
      );
      if (running.exitCode == 10) {
        message = 'This RACE version is already running.';
        return;
      }
      await Process.start(
        exe,
        [],
        workingDirectory: File(exe).parent.path,
        mode: ProcessStartMode.detached,
      );
      message =
          'Opened the selected RACE version. Projects keep their own compatibility settings.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> uninstall(
    EngineBuild build, {
    bool confirmedByUser = false,
  }) async {
    if (!allowed ||
        busy ||
        !Platform.isWindows ||
        selected != build.id ||
        !installs.containsKey(build.id)) {
      return;
    }
    final owner = state;
    final account = owner.scope;
    final entry = Map<String, dynamic>.from(installs[build.id]);
    final exe = entry['executable'] as String;
    final confirmed =
        confirmedByUser ||
        await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text('Uninstall RACE ${build.displayVersion}?'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Remove this app-managed engine version. Other versions, projects and user data are preserved. Close its editor and runtime first. Extra or modified files will stop removal.',
                      ),
                      const SizedBox(height: 16),
                      Text(build.id),
                      const SizedBox(height: 8),
                      SelectableText(
                        exe,
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
                actions: [
                  Pill(
                    'Cancel',
                    onPressed: () => Navigator.pop(dialogContext, false),
                  ),
                  Pill(
                    'Uninstall',
                    onPressed: () => Navigator.pop(dialogContext, true),
                  ),
                ],
              ),
            ) ==
            true;
    if (confirmed != true ||
        !mounted ||
        !allowed ||
        owner.scope != account ||
        selected != build.id ||
        busy) {
      return;
    }
    setState(() {
      busy = true;
      uninstalling = true;
      message = null;
    });
    Directory? temporary;
    http.Client? download;
    String? temporaryParent;
    try {
      final support = await getApplicationSupportDirectory();
      final root = Directory('${support.path}/RACE/versions');
      final expected = File(
        '${root.path}/${build.id}/${build.entrypoint}',
      ).absolute.path.replaceAll('/', Platform.pathSeparator);
      if (File(exe).absolute.path
              .replaceAll('/', Platform.pathSeparator)
              .toLowerCase() !=
          expected.toLowerCase()) {
        throw StateError(
          'This is not an App-managed installation. External folders cannot be removed here.',
        );
      }
      final scratchRoot = await getTemporaryDirectory();
      temporaryParent = await scratchRoot.resolveSymbolicLinks();
      temporary = await scratchRoot.createTemp('ryhze-race-remove-');
      final arguments = <String>[
        '-Root',
        root.path,
        '-BuildId',
        build.id,
        '-Executable',
        exe,
        '-Version',
        build.version,
      ];
      final hash = entry['manifestSha256'];
      if (hash is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
        arguments.addAll(['-ManifestSha256', hash]);
      } else {
        // Authenticate the original inventory before removing legacy managed installs.
        download = http.Client();
        final request =
            http.Request(
                'GET',
                owner.api.resource(
                  unsupported.contains(build.id)
                      ? '/api/engine/releases/${build.id}/uninstall-inventory'
                      : build.url,
                ),
              )
              ..followRedirects = false
              ..headers.addAll(owner.api.authHeaders);
        final response = await download
            .send(request)
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          throw StateError(
            'Connect and sign in to verify this older installation before uninstalling. No files were removed.',
          );
        }
        final archive = File('${temporary.path}/release.zip');
        final sink = archive.openWrite();
        var bytes = 0;
        try {
          await for (final chunk in response.stream.timeout(
            const Duration(seconds: 45),
          )) {
            if (!mounted || !allowed || owner.scope != account) {
              throw StateError('Uninstall cancelled before removal.');
            }
            bytes += chunk.length;
            if (bytes > build.bytes) {
              throw StateError(
                'Invalid original release size. No files were removed.',
              );
            }
            sink.add(chunk);
          }
        } finally {
          await sink.close();
        }
        if (bytes != build.bytes) {
          throw StateError(
            'Incomplete original release. No files were removed.',
          );
        }
        arguments.addAll(['-Archive', archive.path, '-Sha256', build.sha]);
      }
      if (!mounted || !allowed || owner.scope != account) {
        throw StateError('Uninstall cancelled before removal.');
      }
      final script = File('${temporary.path}/uninstall.ps1');
      await script.writeAsString(
        await rootBundle.loadString('assets/update/uninstall-race-version.ps1'),
      );
      if (!mounted || !allowed || owner.scope != account) {
        throw StateError('Uninstall cancelled before removal.');
      }
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        script.path,
        ...arguments,
      ]);
      if (result.exitCode != 0) {
        throw StateError(result.stderr.toString().trim());
      }
      final current = Map<String, dynamic>.from(
        jsonDecode(owner.prefs.getString(installsKey) ?? '{}'),
      );
      if (current[build.id]?['executable'] == exe) current.remove(build.id);
      final saved = await owner.prefs.setString(
        installsKey,
        jsonEncode(current),
      );
      for (final key in [raceDirectoryKey, 'race-located-directory']) {
        final path = owner.prefs.getString(key);
        if (path != null &&
            Directory(path).absolute.path
                    .replaceAll('/', Platform.pathSeparator)
                    .toLowerCase() ==
                File(expected).parent.path.toLowerCase()) {
          await owner.prefs.remove(key);
        }
      }
      if (mounted) {
        setState(() {
          installs = current;
          if (locatedExecutable != null &&
              File(locatedExecutable!).absolute.path
                      .replaceAll('/', Platform.pathSeparator)
                      .toLowerCase() ==
                  expected.toLowerCase()) {
            locatedExecutable = null;
            locatedVersion = null;
          }
          if (!releases.any((release) => release.id == build.id)) {
            releases.add(build);
          }
          message = saved
              ? 'RACE ${build.displayVersion} uninstalled. Other versions, projects and user data were preserved.'
              : 'RACE ${build.displayVersion} uninstalled, but its saved status could not be updated. Refresh versions.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => message = '$error');
    } finally {
      download?.close();
      try {
        if (temporary != null && await temporary.exists()) {
          final resolved = await temporary.resolveSymbolicLinks();
          if (Directory(resolved).parent.path.toLowerCase() !=
                  temporaryParent?.toLowerCase() ||
              !resolved
                  .split(Platform.pathSeparator)
                  .last
                  .startsWith('ryhze-race-remove-')) {
            throw const FileSystemException(
              'Temporary verification path changed.',
            );
          }
          await temporary.delete(recursive: true);
        }
      } catch (_) {
        if (mounted) {
          message =
              '${message ?? ''} Temporary verification files could not be cleared.';
        }
      }
      if (mounted) {
        setState(() {
          busy = false;
          uninstalling = false;
        });
      }
    }
  }

  Future<void> locate() async {
    final path = await raceChannel.invokeMethod<String>('pickExecutable');
    if (path == null || !mounted || !allowed) return;
    final value = await raceInstallation(directory: path, strict: true);
    if (value == null) {
      throw StateError('Choose RACE.exe from a complete installation.');
    }
    await state.prefs.setString('race-located-directory', value['path']);
    final managed = await reconcileLocated(value);
    if (!mounted || !allowed) return;
    await select(managed ?? 'located');
  }

  @override
  Widget build(BuildContext context) {
    if (!allowed) return const SizedBox.shrink();
    final available = {for (final r in releases) r.id: r};
    for (final entry in installs.entries) {
      available.putIfAbsent(
        entry.key,
        () => EngineBuild.fromJson(
          Map<String, dynamic>.from(entry.value['release']),
        ),
      );
    }
    final build = available[selected];
    final latest = releases.firstOrNull;
    final retired = unsupported.contains(selected);
    final showPlanned = !available.values.any((r) => r.version == '0.1.0');
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.horizontalPadding ?? 22,
        vertical: widget.artworkBuilder == null ? 24 : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.artworkBuilder != null) ...[
            widget.artworkBuilder!(build),
            const SizedBox(height: 24),
          ],
          if (!widget.embedded) ...[
            const Eyebrow('Ryhze Engine'),
            const SizedBox(height: 12),
            Text('RACE versions', style: heading(32)),
          ],
          const Text(
            'Install versions side by side and choose which one to open. Switching versions does not change project compatibility.',
          ),
          const SizedBox(height: 20),
          if (showPlanned) ...[
            Text('V0.1.0 — Unstable', style: heading(22)),
            const SizedBox(height: 8),
            const Text(
              'Planned release · Not available to download yet.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 20),
          ],
          if (latest != null) ...[
            Text(
              'Latest release: RACE ${latest.displayVersion}',
              style: heading(22),
            ),
            const SizedBox(height: 8),
            Text(
              selected == 'located'
                  ? 'Selected: Local installation (unverified)'
                  : build == null
                  ? 'Choose a version below.'
                  : 'Selected: RACE ${build.displayVersion} - ${executable != null ? 'Installed' : 'Not installed'}',
              style: const TextStyle(color: muted),
            ),
            if (selected != latest.id) ...[
              const SizedBox(height: 12),
              Pill(
                'Choose latest version',
                icon: Icons.system_update_alt,
                onPressed: busy ? null : () => select(latest.id),
              ),
            ],
            const SizedBox(height: 20),
          ],
          if (!Platform.isWindows)
            const Text('Install and launch RACE from Ryhze on Windows.'),
          if (available.isNotEmpty || locatedExecutable != null)
            RyhzeDropdown<String>(
              fullWidthMenu: true,
              value: selected,
              isExpanded: true,
              items: [
                if (showPlanned)
                  const DropdownMenuItem(
                    enabled: false,
                    child: Text('V0.1.0 — Unstable · Planned'),
                  ),
                for (final r in available.values)
                  DropdownMenuItem(
                    value: r.id,
                    child: Text(
                      '${r.displayLabel}${installs.containsKey(r.id) ? ' - Installed' : ''}',
                    ),
                  ),
                if (locatedExecutable != null) ...[
                  const DropdownMenuItem(
                    enabled: false,
                    child: Text('On this device'),
                  ),
                  const DropdownMenuItem(
                    value: 'located',
                    child: Text('Local installation (unverified)'),
                  ),
                ],
              ],
              onChanged: busy
                  ? null
                  : (id) {
                      if (id != null) unawaited(select(id));
                    },
            ),
          if (state.adminAccess) ...[
            const SizedBox(height: 16),
            Pill(
              'Manage versions',
              icon: Icons.edit_outlined,
              onPressed: busy
                  ? null
                  : () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              EngineEditor(state: state, selectedId: selected),
                        ),
                      );
                      if (mounted && allowed) await refresh();
                    },
            ),
          ],
          if (retired)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('Old version is no longer supported'),
            ),
          if (selected == 'located')
            Text(
              '${localEngineVersionDescription(locatedVersion)}\n$locatedExecutable',
              style: const TextStyle(color: muted),
            ),
          if (build != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Development build · Stability not guaranteed.',
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "What's in RACE ${build.displayVersion}",
                    style: heading(24),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    build.notes.isEmpty
                        ? 'Release notes are not available for this build yet.'
                        : build.notes,
                    style: const TextStyle(height: 1.6),
                  ),
                  const SizedBox(height: 20),
                  if (build.media.isNotEmpty || build.demo != null) ...[
                    EngineVersionGallery(
                      key: ValueKey(
                        '${build.id}:${state.scope}:${build.media}',
                      ),
                      state: state,
                      build: build,
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (build.demo case final demo?) ...[
                    Text('Tech demo', style: heading(20)),
                    if (demo.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        demo.description,
                        style: const TextStyle(color: muted, height: 1.5),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ] else
                    const Text(
                      'Tech demo not available for this build yet.',
                      style: TextStyle(color: muted),
                    ),
                ],
              ),
            ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(message!),
            ),
          if (busy) ...[
            StatusProgress(
              label: downloaded
                  ? 'Download complete'
                  : uninstalling
                  ? 'Verifying and uninstalling selected version'
                  : installing
                  ? 'Installing and verifying files'
                  : downloading
                  ? 'Downloading'
                  : 'Checking RACE',
              value: downloaded
                  ? 1
                  : downloading
                  ? progress
                  : null,
            ),
            if (downloaded)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  installing
                      ? 'Installing selected version…'
                      : 'Verifying downloaded package…',
                  style: const TextStyle(color: muted),
                ),
              ),
            const SizedBox(height: 16),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (Platform.isWindows && executable != null && !retired)
                Pill(
                  'Launch selected version',
                  primary: true,
                  icon: Icons.play_arrow,
                  onPressed: busy ? null : () => attempt(context, launch),
                ),
              if (Platform.isWindows &&
                  build != null &&
                  installs.containsKey(build.id))
                Pill(
                  'Uninstall selected version',
                  icon: Icons.delete_outline,
                  onPressed: busy ? null : () => uninstall(build),
                ),
              if (Platform.isWindows &&
                  build != null &&
                  !installs.containsKey(build.id) &&
                  !retired)
                Pill(
                  'Install selected version',
                  primary: true,
                  icon: Icons.download,
                  onPressed: busy || !state.engineDownloadAccess
                      ? null
                      : () => install(build),
                ),
              Pill(
                'Refresh versions',
                icon: Icons.refresh,
                onPressed: busy ? null : refresh,
              ),
              if (Platform.isWindows)
                Pill(
                  'Locate RACE',
                  icon: Icons.folder_open,
                  onPressed: busy ? null : () => attempt(context, locate),
                ),
              if (downloading) Pill('Cancel download', onPressed: cancel),
            ],
          ),
          if (!state.engineDownloadAccess) ...[
            const SizedBox(height: 12),
            const Text(
              'Engine downloads are paused. An administrator can allow access in Manage Members. Your installed versions and projects are kept.',
            ),
            Pill(
              'Check engine access',
              onPressed: busy
                  ? null
                  : () => attempt(context, () async {
                      await state.authorizeEngineInstall();
                      if (mounted) setState(() {});
                    }),
            ),
          ],
        ],
      ),
    );
  }
}
