import 'package:flutter/material.dart';
import '../core/updates.dart';
import 'design.dart';

class UpdateBanner extends StatelessWidget {
  final AppUpdates updates;
  final VoidCallback onOpen;
  const UpdateBanner({super.key, required this.updates, required this.onOpen});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updates,
    builder: (_, _) => !updates.showBanner
        ? const SizedBox.shrink()
        : Material(
            color: const Color(0xff201337),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.system_update_alt, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Ryhze update available',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(onPressed: onOpen, child: const Text('View')),
                  IconButton(
                    onPressed: updates.dismiss,
                    tooltip: 'Remind me later',
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          ),
  );
}

class UpdatePanel extends StatelessWidget {
  final AppUpdates updates;
  const UpdatePanel({super.key, required this.updates});
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(20),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Glass(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: updates,
            builder: (_, _) {
              final update = updates.release;
              final phase = updates.phase;
              final title = switch (phase) {
                UpdatePhase.checking => 'Checking for updates',
                UpdatePhase.current => 'You’re up to date',
                UpdatePhase.downloading => 'Downloading update',
                UpdatePhase.ready => 'Ready to install',
                UpdatePhase.installing => 'Starting installation',
                _ => updates.available ? 'Update available' : 'App updates',
              };
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Eyebrow('RYHZE UPDATES')),
                      IconButton(
                        tooltip: 'Close updates',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Installed version $appVersion',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  if (updates.available && update != null) ...[
                    Text(
                      'Ryhze ${update.version} · ${(update.bytes / 1048576).toStringAsFixed(1)} MB',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      update.notes,
                      style: const TextStyle(
                        fontSize: 13,
                        color: muted,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (phase == UpdatePhase.checking ||
                      phase == UpdatePhase.installing)
                    const LinearProgressIndicator(minHeight: 3),
                  if (phase == UpdatePhase.downloading) ...[
                    LinearProgressIndicator(
                      value: updates.progress,
                      minHeight: 3,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(updates.progress * 100).floor()}% downloaded',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: updates.cancelDownload,
                      child: const Text('Cancel download'),
                    ),
                  ],
                  if (updates.error != null) ...[
                    Text(
                      updates.error!,
                      style: const TextStyle(
                        color: Color(0xffffbdbd),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (updates.instruction != null) ...[
                    Text(
                      updates.instruction!,
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (!updates.busy) ...[
                    if (phase == UpdatePhase.ready) ...[
                      Text(
                        updates.platform == 'windows'
                            ? 'Ryhze will close briefly, install the update, and reopen. Your preferences and saved list stay in place.'
                            : 'Android will ask you to confirm the installation. Your preferences and saved list stay in place.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: muted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Pill(
                        updates.platform == 'windows'
                            ? 'Install and restart'
                            : 'Install update',
                        primary: true,
                        icon: Icons.system_update_alt,
                        onPressed: updates.install,
                      ),
                    ] else if (updates.available)
                      Pill(
                        'Download update',
                        primary: true,
                        icon: Icons.download,
                        onPressed: updates.download,
                      )
                    else
                      Pill(
                        'Check for updates',
                        primary: true,
                        icon: Icons.refresh,
                        onPressed: updates.check,
                      ),
                    if (updates.available)
                      TextButton(
                        onPressed: updates.check,
                        child: const Text('Check again'),
                      ),
                  ],
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
