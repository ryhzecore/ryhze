import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/updates.dart';
import 'design.dart';

class ReportBugPanel extends StatelessWidget {
  const ReportBugPanel({super.key});
  static const address = 'support@ryhze.com';

  Future<void> openEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: address,
      query:
          {
                'subject': 'Ryhze $appVersion bug report',
                'body':
                    'Ryhze $appVersion (build $appBuild)\n\n'
                    'Device:\n\nWhat happened:\n\nSteps to reproduce:\n\n'
                    'What I expected:\n',
              }.entries
              .map(
                (e) =>
                    '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
              )
              .join('&'),
    );
    try {
      if (await launchUrl(uri)) return;
    } catch (_) {
      // The address remains available when no email app is installed.
    }
    if (context.mounted) {
      toast(context, 'Email $address with the details of the bug.');
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(20),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Glass(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Report Bug', style: heading(26))),
                  IconButton(
                    tooltip: 'Close bug report',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Tell us what happened, your device and the steps to repeat it. You can attach a screenshot in your email.',
              ),
              const SizedBox(height: 16),
              const SelectableText(address),
              const SizedBox(height: 8),
              const Text('Ryhze $appVersion', style: TextStyle(color: muted)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton(
                    autofocus: true,
                    onPressed: () => openEmail(context),
                    child: const Text('Open email'),
                  ),
                  TextButton(
                    onPressed: () => attempt(context, () async {
                      await Clipboard.setData(
                        const ClipboardData(text: address),
                      );
                      if (context.mounted) {
                        toast(context, 'Email address copied.');
                      }
                    }),
                    child: const Text('Copy email'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
