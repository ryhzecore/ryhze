import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/state.dart';
import 'design.dart';
import 'player.dart';

class EngineDemoArtwork extends StatefulWidget {
  final RyhzeState state;
  final String buildId;
  final EngineDemo demo;
  final Widget poster;
  final double aspectRatio;
  const EngineDemoArtwork({
    super.key,
    required this.state,
    required this.buildId,
    required this.demo,
    required this.poster,
    required this.aspectRatio,
  });
  @override
  State<EngineDemoArtwork> createState() => _EngineDemoArtworkState();
}

class _EngineDemoArtworkState extends State<EngineDemoArtwork> {
  late final account = widget.state.scope;
  @override
  Widget build(BuildContext context) => RyhzePlayer(
    key: ValueKey('${widget.buildId}:${widget.demo.sha256}:$account'),
    state: widget.state,
    title: RyhzeTitle(
      id: 'race-demo-${widget.buildId}',
      title: widget.demo.title,
      kind: 'demo',
      label: 'Tech demo',
      status: '',
      description: widget.demo.description,
      streams: [widget.demo.url],
    ),
    poster: widget.poster,
    frameAspectRatio: widget.aspectRatio,
    recordProgress: false,
    canPlay: () => widget.state.scope == account && widget.state.engineAccess,
  );
}

class EngineDemo {
  final String title, description, url, sha256;
  final int bytes;
  EngineDemo.fromJson(Map<String, dynamic> json, String buildId)
    : title = json['title'] as String,
      description = json['description'] as String? ?? '',
      url = json['url'] as String,
      sha256 = json['sha256'] as String,
      bytes = json['bytes'] as int {
    if (title.trim().isEmpty ||
        title.length > 160 ||
        description.length > 2000 ||
        (url != '/api/engine/releases/$buildId/demo' &&
            !RegExp(
              r'^/api/engine/releases/media/[a-f0-9-]{36}$',
            ).hasMatch(url)) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256) ||
        bytes <= 0 ||
        bytes > 4 * 1024 * 1024 * 1024 ||
        json['mime'] != 'video/mp4') {
      throw const FormatException('Invalid RACE demo metadata.');
    }
  }
  static EngineDemo? parse(Object? value, String buildId) {
    if (value is! Map) return null;
    try {
      return EngineDemo.fromJson(Map<String, dynamic>.from(value), buildId);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'url': url,
    'sha256': sha256,
    'bytes': bytes,
    'mime': 'video/mp4',
  };
}

class EngineDemoPage extends StatefulWidget {
  final RyhzeState state;
  final String buildId, version;
  final EngineDemo demo;
  const EngineDemoPage({
    super.key,
    required this.state,
    required this.buildId,
    required this.version,
    required this.demo,
  });
  @override
  State<EngineDemoPage> createState() => _EngineDemoPageState();
}

class _EngineDemoPageState extends State<EngineDemoPage> {
  late final String account = widget.state.scope;
  bool get allowed =>
      widget.state.scope == account && widget.state.engineAccess;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.state,
    builder: (context, _) => Scaffold(
      backgroundColor: canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Pill(
                      'Back',
                      icon: Icons.arrow_back,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!allowed)
                    const Text(
                      'Sign in with an authorised RACE account to watch this demo.',
                    )
                  else ...[
                    Eyebrow('RACE ${widget.version} \u00b7 Tech demo'),
                    const SizedBox(height: 12),
                    Text(widget.demo.title, style: heading(30)),
                    const SizedBox(height: 12),
                    if (widget.demo.description.isNotEmpty) ...[
                      Text(
                        widget.demo.description,
                        style: const TextStyle(color: muted, height: 1.6),
                      ),
                      const SizedBox(height: 20),
                    ],
                    RyhzePlayer(
                      key: ValueKey('${widget.buildId}:$account'),
                      title: RyhzeTitle(
                        id: 'race-demo-${widget.buildId}',
                        title: widget.demo.title,
                        kind: 'demo',
                        label: 'RACE ${widget.version}',
                        status: '',
                        description: widget.demo.description,
                        streams: [widget.demo.url],
                      ),
                      state: widget.state,
                      recordProgress: false,
                      canPlay: () => allowed,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.buildId,
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
