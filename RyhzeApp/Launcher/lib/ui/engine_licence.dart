import 'package:flutter/material.dart';
import '../core/engine_licence.dart';
import 'agreement_dialog.dart';

/// The RACE licence for one release, read to the end before Install enables.
///
/// A thin wrapper over [AgreementDialog] so the engine licence and the tester
/// agreement behave identically. The release identity is part of the key, so
/// a different release starts the reading again.
class EngineLicenceDialog extends StatelessWidget {
  final String releaseId, version;
  final EngineLicence licence;
  final Listenable authorization;
  final bool Function() canInstall;
  const EngineLicenceDialog({
    super.key,
    required this.releaseId,
    required this.version,
    required this.licence,
    required this.authorization,
    required this.canInstall,
  });

  @override
  Widget build(BuildContext context) => AgreementDialog(
    key: ValueKey('race-licence:$releaseId:${licence.digest}'),
    title: 'RACE $version licence agreement',
    intro: 'Read the agreement and third-party notices, then confirm below.',
    text: licence.text,
    checkboxLabel: 'I have read and agree to the licence agreement.',
    confirmLabel: 'Agree and install',
    authorization: authorization,
    canConfirm: canInstall,
    blockedMessage: 'Your access changed. Close this dialog and sign in again.',
    scrollKey: const ValueKey('race-licence-scroll'),
  );
}
