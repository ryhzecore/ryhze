import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/models.dart';
import '../core/state.dart';
import 'design.dart';

class GamePackages extends StatefulWidget {
  final RyhzeTitle title;
  final RyhzeState state;
  const GamePackages({super.key, required this.title, required this.state});
  @override
  State<GamePackages> createState() => _GamePackagesState();
}

class _GamePackagesState extends State<GamePackages> {
  String? progress, error, downloaded;
  double? downloadProgress;
  Future<void> download(Map<String, dynamic> package) async {
    if (widget.state.user == null) {
      setState(() => error = 'Sign in to download this game.');
      return;
    }
    setState(() {
      downloadProgress = 0;
      progress = 'Downloading…';
      error = null;
      downloaded = null;
    });
    File? file;
    final client = http.Client();
    try {
      final directory = await getApplicationSupportDirectory();
      final folder = Directory(
        '${directory.path}${Platform.pathSeparator}game-packages',
      );
      await folder.create(recursive: true);
      final uri = widget.state.api.resource(package['url']);
      final req = http.Request('GET', uri)
        ..followRedirects = false
        ..headers.addAll(widget.state.api.authHeaders);
      final response = await client
          .send(req)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw Exception('Package is unavailable.');
      }
      final disposition = response.headers['content-disposition'] ?? '';
      final encoded = RegExp(
        "filename\\*=UTF-8''([^;]+)",
      ).firstMatch(disposition)?.group(1);
      final name = encoded == null
          ? 'game-package.zip'
          : Uri.decodeComponent(encoded);
      final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      file = File(
        '${folder.path}${Platform.pathSeparator}${package['id']}-$safeName.part',
      );
      final sink = file.openWrite();
      var count = 0;
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 60),
        )) {
          count += chunk.length;
          if (count > (package['bytes'] as int)) {
            throw Exception('Package exceeds the expected size.');
          }
          sink.add(chunk);
          if (mounted) {
            setState(() {
              progress = 'Downloading';
              downloadProgress = count / (package['bytes'] as int);
            });
          }
        }
      } finally {
        await sink.close();
      }
      if (count != package['bytes']) throw Exception('Incomplete download.');
      if (mounted) {
        setState(() {
          progress = 'Verifying download';
          downloadProgress = null;
        });
      }
      final digest = await sha256.bind(file.openRead()).first;
      if (digest.toString() != package['sha256']) {
        throw Exception('Package checksum verification failed.');
      }
      final completed = await file.rename(
        file.path.substring(0, file.path.length - 5),
      );
      if (mounted) setState(() => downloaded = completed.path);
    } catch (e) {
      if (file != null && await file.exists()) await file.delete();
      if (mounted) setState(() => error = '$e');
    } finally {
      client.close();
      if (mounted) setState(() => progress = null);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final p in widget.title.packages)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: OutlinedButton(
            onPressed: progress == null ? () => download(p) : null,
            child: Text('Download ${p['platform']} · ${p['version']}'),
          ),
        ),
      if (progress != null)
        StatusProgress(label: progress!, value: downloadProgress),
      if (error != null)
        Text(error!, style: const TextStyle(color: Colors.orangeAccent)),
      if (downloaded != null) ...[
        const Text(
          'Download verified. Open only when you are ready to install or extract it.',
        ),
        SelectableText(downloaded!),
        TextButton(
          onPressed: () => launchUrl(
            Uri.file(downloaded!),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('Open downloaded package'),
        ),
      ],
      if (widget.title.storeUrl.isNotEmpty)
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse(widget.title.storeUrl),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('Visit store'),
        ),
      for (final s in widget.title.screenshots)
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.network(
                  widget.state.api.resource(s['url']).toString(),
                  headers: widget.state.api.authHeaders,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Text('Screenshot unavailable'),
                ),
              ),
              if ((s['caption'] ?? '').isNotEmpty) Text(s['caption']),
            ],
          ),
        ),
    ],
  );
}
