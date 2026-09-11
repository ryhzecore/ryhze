import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../core/state.dart';
import '../core/updates.dart';
import 'design.dart';
import '../core/race_installation.dart';
export '../core/race_installation.dart' show raceInstallation;

class InstalledEngineCard extends StatefulWidget {
  final RyhzeState state;
  final VoidCallback onOpen;
  const InstalledEngineCard({
    super.key,
    required this.state,
    required this.onOpen,
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
    installation = raceInstallation(
      directory: widget.state.prefs.getString(raceDirectoryKey),
    );
    refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => refresh(),
    );
  }

  void refresh() {
    if (!mounted || widget.state.user?.launcherAdmin != true) return;
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

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: installation,
    builder: (context, snapshot) {
      if (widget.state.user?.launcherAdmin != true) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Glass(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.view_in_ar_outlined, size: 32),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RACE', style: heading(28)),
                        Text(
                          snapshot.data != null
                              ? 'Installed · ${snapshot.data!['version']}'
                              : snapshot.connectionState ==
                                    ConnectionState.waiting
                              ? 'Checking this PC…'
                              : 'Install or locate your engine',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Pill(
                snapshot.data != null ? 'Open engine' : 'Manage engine',
                icon: Icons.arrow_forward,
                onPressed: widget.onOpen,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class EnginePage extends StatefulWidget {
  final RyhzeState state;
  final double? horizontalPadding;
  const EnginePage({super.key, required this.state, this.horizontalPadding});
  @override
  State<EnginePage> createState() => _EnginePageState();
}

class _EnginePageState extends State<EnginePage> with WidgetsBindingObserver {
  AppRelease? release;
  String? message, executable, installedVersion;
  int installedBuild = 0;
  double progress = 0;
  bool busy = false, downloading = false, installing = false;
  http.Client? client;
  Timer? timer;
  int operation = 0;
  bool get allowed => widget.state.user?.launcherAdmin == true;
  @override
  void initState() {
    super.initState();
    widget.state.addListener(accountChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(check());
    timer = Timer.periodic(const Duration(hours: 6), (_) {
      if (!busy) unawaited(check());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    if (value == AppLifecycleState.resumed && !busy) unawaited(check());
  }

  void accountChanged() {
    if (!allowed) cancel();
  }

  @override
  void dispose() {
    widget.state.removeListener(accountChanged);
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    operation++;
    client?.close();
    super.dispose();
  }

  void cancel() {
    operation++;
    client?.close();
    client = null;
    if (mounted) {
      setState(() {
        busy = false;
        downloading = false;
        message = 'Download cancelled.';
      });
    }
  }

  Future<void> installed() async {
    final value = await raceInstallation(
      directory: widget.state.prefs.getString(raceDirectoryKey),
    );
    executable = value?['executable'] as String?;
    installedBuild = int.tryParse('${value?['build']}') ?? 0;
    installedVersion = value?['version'] as String?;
  }

  Future<void> check() async {
    if (!allowed || busy) return;
    final generation = ++operation;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await installed();
      if (generation != operation || !mounted || !allowed) return;
      setState(() {});
      final data = await widget.state.api.request('/api/admin/race/manifest');
      if (generation != operation || !mounted || !allowed) return;
      if (data['available'] == false) {
        release = null;
        message = executable != null
            ? 'RACE is installed on this PC. Online updates are not available yet.'
            : data['message'] as String?;
      } else {
        release = await AppRelease.verify(
          jsonEncode(data),
          'windows',
          product: 'RACE',
        );
      }
    } catch (e) {
      if (mounted && generation == operation) message = '$e';
    } finally {
      if (mounted && generation == operation) setState(() => busy = false);
    }
  }

  Future<void> install() async {
    final expected = release;
    if (!allowed || busy || expected == null || !Platform.isWindows) return;
    final generation = ++operation;
    setState(() {
      busy = true;
      downloading = true;
      progress = 0;
      message = null;
    });
    File? package;
    http.Client? ownedClient;
    try {
      // Reauthorize and reverify the current release before each download.
      final data = await widget.state.api.request('/api/admin/race/manifest');
      final verified = await AppRelease.verify(
        jsonEncode(data),
        'windows',
        product: 'RACE',
      );
      if (verified?.sha256 != expected.sha256) {
        throw StateError('The RACE release changed. Check for updates again.');
      }
      final folder = Directory(
        '${(await getTemporaryDirectory()).path}/ryhze-race-${DateTime.now().microsecondsSinceEpoch}',
      );
      await folder.create();
      package = File('${folder.path}/${expected.filename}');
      final activeClient = ownedClient = client = http.Client();
      final request = http.Request(
        'GET',
        widget.state.api.resource(expected.path),
      )..followRedirects = false;
      request.headers.addAll(widget.state.api.authHeaders);
      final response = await activeClient
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw StateError('RACE download requires an active admin sign-in.');
      }
      final sink = package.openWrite();
      var bytes = 0;
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 45),
        )) {
          if (generation != operation || !allowed) {
            throw StateError('Download cancelled.');
          }
          bytes += chunk.length;
          if (bytes > expected.bytes) throw StateError('Invalid package size.');
          sink.add(chunk);
          if (mounted) setState(() => progress = bytes / expected.bytes);
        }
      } finally {
        await sink.close();
      }
      final digest = await sha256.bind(package.openRead()).first;
      if (bytes != expected.bytes || digest.toString() != expected.sha256) {
        throw StateError('RACE package verification failed.');
      }
      if (!mounted || generation != operation || !allowed) return;
      await widget.state.api.request('/api/admin/race/manifest');
      if (!mounted || generation != operation || !allowed) return;
      setState(() {
        downloading = false;
        installing = true;
      });
      final process = await Process.start(package.path, []);
      if (await process.exitCode != 0) {
        throw StateError('RACE setup did not complete.');
      }
      await installed();
      if (installedBuild < expected.build) {
        throw StateError('RACE installation was cancelled or did not finish.');
      }
      message = 'RACE $installedVersion is installed.';
    } catch (e) {
      if (mounted && generation == operation) message = '$e';
    } finally {
      ownedClient?.close();
      if (identical(client, ownedClient)) client = null;
      if (package != null && await package.exists()) await package.delete();
      if (mounted && generation == operation) {
        setState(() {
          busy = false;
          downloading = false;
          installing = false;
        });
      }
    }
  }

  Future<void> locate() async {
    final selected = await raceChannel.invokeMethod<String>('pickExecutable');
    if (selected == null || selected.isEmpty || !mounted || !allowed) return;
    final value = await raceInstallation(directory: selected, strict: true);
    if (value == null) {
      throw StateError(
        'Choose race_editor.exe from a complete RACE installation.',
      );
    }
    await widget.state.prefs.setString(
      raceDirectoryKey,
      value['path'] as String,
    );
    if (mounted && allowed) {
      setState(() {
        executable = value['executable'] as String;
        installedVersion = value['version'] as String;
        installedBuild = (value['build'] as num?)?.toInt() ?? 0;
      });
    }
  }

  Future<void> open() async {
    if (!allowed || executable == null || downloading || installing) return;
    await widget.state.api.request('/api/admin/race/manifest');
    if (mounted && allowed) {
      await Process.start(
        executable!,
        [],
        mode: ProcessStartMode.detached,
        workingDirectory: File(executable!).parent.path,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!allowed) return const SizedBox.shrink();
    final update = release != null && release!.build > installedBuild;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal:
            widget.horizontalPadding ??
            (MediaQuery.sizeOf(context).width <= 700 ? 22 : 56),
        vertical: MediaQuery.sizeOf(context).width <= 700 ? 32 : 56,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Ryhze Advanced Creation Engine'),
          const SizedBox(height: 20),
          Text('RACE', style: heading(64)),
          const SizedBox(height: 20),
          const Text(
            'Your engine workspace, installed and updated through Ryhze.',
          ),
          const SizedBox(height: 30),
          if (!Platform.isWindows)
            const Text(
              'RACE runs on Windows. Sign in to Ryhze on your PC to install it.',
            ),
          if (installedVersion != null) Text('Installed: $installedVersion'),
          if (release != null) Text('Latest: ${release!.version}'),
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(message!),
            ),
          if (busy)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    installing
                        ? 'Complete RACE setup in the installer.'
                        : downloading
                        ? 'Downloading ${(progress * 100).round()}%'
                        : 'Checking for updates…',
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: downloading ? progress : null),
                ],
              ),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (Platform.isWindows && executable != null)
                Pill(
                  'Open RACE',
                  primary: true,
                  icon: Icons.arrow_forward,
                  onPressed: downloading || installing
                      ? null
                      : () => attempt(context, open),
                ),
              if (Platform.isWindows && update)
                Pill(
                  installedBuild == 0 ? 'Install RACE' : 'Update RACE',
                  primary: true,
                  icon: Icons.download,
                  onPressed: busy ? null : install,
                ),
              Pill(
                'Check for updates',
                icon: Icons.refresh,
                onPressed: busy ? null : check,
              ),
              if (Platform.isWindows)
                Pill(
                  'Locate RACE',
                  icon: Icons.folder_open,
                  onPressed: downloading || installing
                      ? null
                      : () => attempt(context, locate),
                ),
              if (downloading) Pill('Cancel download', onPressed: cancel),
            ],
          ),
          if (release != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(release!.notes),
            ),
        ],
      ),
    );
  }
}
