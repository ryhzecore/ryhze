import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/state.dart';
import 'design.dart';
import 'engine.dart';
import 'engine_versions.dart';

List<EngineBuild> unsupportedManagedBuilds(
  String? stored,
  Iterable<dynamic> unsupported,
) {
  final result = <EngineBuild>[];
  try {
    final entries = jsonDecode(stored ?? '{}') as Map;
    for (final id in unsupported) {
      try {
        final entry = entries[id] as Map;
        final release = EngineBuild.fromJson(
          Map<String, dynamic>.from(entry['release']),
        );
        if (release.id == id && entry['executable'] is String) {
          result.add(release);
        }
      } catch (_) {
        /* A malformed local entry cannot authorise removal. */
      }
    }
  } catch (_) {
    /* An unavailable local list is not an installation. */
  }
  return result;
}

Future<bool> confirmUnsupportedEngineRemoval(
  BuildContext context,
  RyhzeState state,
  EngineBuild build,
) async {
  final account = state.scope;
  bool allowed() =>
      context.mounted && state.engineAccess && state.scope == account;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => ListenableBuilder(
      listenable: state,
      builder: (_, _) => AlertDialog(
        title: Text(
          allowed()
              ? 'Old version is no longer supported'
              : 'Engine access is off.',
        ),
        content: allowed() ? Text('RACE ${build.displayVersion}') : null,
        actions: [
          if (allowed())
            Pill(
              'Proceed with uninstalling',
              onPressed: () => Navigator.pop(dialog, true),
            ),
        ],
      ),
    ),
  );
  return allowed() && confirmed == true;
}

Future<void> offerUnsupportedEngineRemoval(
  BuildContext context,
  RyhzeState state,
  List<EngineBuild> builds,
) async {
  final account = state.scope;
  bool allowed() =>
      context.mounted && state.engineAccess && state.scope == account;
  for (final build in builds) {
    if (!allowed()) return;
    final installs =
        jsonDecode(state.prefs.getString('race-managed-installations') ?? '{}')
            as Map;
    final exe = installs[build.id]?['executable'];
    if (exe is! String || !await File(exe).exists() || !allowed()) continue;
    if (!context.mounted) return;
    final confirmed = await confirmUnsupportedEngineRemoval(
      context,
      state,
      build,
    );
    if (!context.mounted || !allowed()) return;
    if (confirmed == true) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              RaceDetail(state: state, uninstallRequested: build.id),
        ),
      );
    }
  }
}
