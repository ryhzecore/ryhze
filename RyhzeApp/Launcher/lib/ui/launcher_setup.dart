import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/steamdeck_startup.dart';
import 'design.dart';

/// Defers other startup prompts until the in-app launcher choice is finished.
class LauncherSetupGate extends StatefulWidget {
  final bool requested;
  final bool ready;
  final Widget Function(bool blocked) builder;
  final SteamDeckStartup startup;
  final Future<void> Function()? openSteam;
  const LauncherSetupGate({
    super.key,
    required this.requested,
    required this.ready,
    required this.builder,
    this.startup = const SteamDeckStartup(),
    this.openSteam,
  });
  @override
  State<LauncherSetupGate> createState() => _LauncherSetupGateState();
}

class _LauncherSetupGateState extends State<LauncherSetupGate> {
  late bool pending = widget.requested;
  bool scheduled = false;
  @override
  void initState() {
    super.initState();
    schedule();
  }

  @override
  void didUpdateWidget(covariant LauncherSetupGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    schedule();
  }

  void schedule() {
    if (!pending || !widget.ready || scheduled) return;
    scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => LauncherChoiceDialog(
          startup: widget.startup,
          openSteam: widget.openSteam,
        ),
      );
      if (mounted) setState(() => pending = false);
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(pending);
}

class LauncherChoiceDialog extends StatefulWidget {
  final SteamDeckStartup startup;
  final Future<void> Function()? openSteam;
  const LauncherChoiceDialog({
    super.key,
    this.startup = const SteamDeckStartup(),
    this.openSteam,
  });
  @override
  State<LauncherChoiceDialog> createState() => _LauncherChoiceDialogState();
}

class _LauncherChoiceDialogState extends State<LauncherChoiceDialog> {
  bool busy = false;
  String? error;
  Future<void> choose(bool ryhze) async {
    setState(() {
      busy = true;
      error = null;
    });
    bool saved = false;
    try {
      if (await widget.startup.setEnabled(ryhze) != ryhze) {
        throw StateError('SteamOS did not confirm your choice.');
      }
      saved = true;
      if (!ryhze) {
        if (widget.openSteam != null) {
          await widget.openSteam!();
        } else if (!await launchUrl(
          Uri.parse('steam://open/bigpicture'),
          mode: LaunchMode.externalApplication,
        )) {
          throw StateError('Steam could not open.');
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          error =
              '${saved ? 'Your startup choice was saved. ' : ''}'
              '${e.toString().replaceFirst('Bad state: ', '')}';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Choose your home'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Steam opens Gaming Mode on startup. Ryhze opens Desktop Mode '
                'and starts Big Picture. Your current session stays open.',
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      autofocus: true,
                      onPressed: busy ? null : () => choose(false),
                      icon: const Icon(Icons.sports_esports_outlined),
                      label: const Text('Steam'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : () => choose(true),
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Ryhze'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Change this later in Settings → Launch Home. '
                'On is Ryhze. Off is Steam.',
                style: TextStyle(fontSize: 13, color: muted),
              ),
              if (busy) ...[
                const SizedBox(height: 16),
                const StatusProgress(),
                const SizedBox(height: 8),
                const Text('Saving your choice…'),
              ],
              if (error != null) ...[const SizedBox(height: 16), Text(error!)],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Not now'),
        ),
      ],
    ),
  );
}
