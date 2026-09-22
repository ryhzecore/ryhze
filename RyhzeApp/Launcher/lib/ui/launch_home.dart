import 'package:flutter/material.dart';
import '../core/steamdeck_startup.dart';

class LaunchHomeSetting extends StatefulWidget {
  final SteamDeckStartup startup;
  const LaunchHomeSetting({super.key, this.startup = const SteamDeckStartup()});
  @override
  State<LaunchHomeSetting> createState() => _LaunchHomeSettingState();
}

class _LaunchHomeSettingState extends State<LaunchHomeSetting> {
  bool? enabled;
  bool busy = true;
  String? error, saved;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await widget.startup.read();
      if (mounted) setState(() => enabled = value);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> change(bool value) async {
    setState(() {
      busy = true;
      error = null;
      saved = null;
    });
    try {
      final confirmed = await widget.startup.setEnabled(value);
      if (mounted) {
        setState(() {
          enabled = confirmed;
          saved = confirmed
              ? 'Next startup: Ryhze Big Picture.'
              : 'Next startup: Steam Gaming Mode.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          enabled = null;
        });
      }
      // Never display a remembered switch value as confirmed after a failed write.
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      SwitchListTile(
        key: const ValueKey('launch-home-toggle'),
        contentPadding: EdgeInsets.zero,
        title: const Text('Launch Home', style: TextStyle(fontSize: 13)),
        subtitle: Text(
          busy
              ? 'Checking SteamOS…'
              : error != null
              ? 'Startup setting unavailable'
              : enabled == null
              ? 'Currently: Desktop Mode. Turn on for Ryhze.'
              : 'On: Ryhze · Off: Steam',
          style: const TextStyle(fontSize: 12),
        ),
        value: enabled ?? false,
        onChanged: busy || error != null ? null : change,
      ),
      if (saved != null) Text(saved!, style: const TextStyle(fontSize: 12)),
      if (error != null) ...[
        Text(error!, style: const TextStyle(fontSize: 12)),
        TextButton(onPressed: busy ? null : load, child: const Text('Retry')),
      ],
    ],
  );
}
