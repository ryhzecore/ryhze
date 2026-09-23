import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../core/state.dart';
import 'design.dart';

Future<Map<String, dynamic>?> uploadPublishingFile(
  BuildContext context,
  RyhzeState state,
  String gameId,
  String target,
  void Function(String) progress, {
  bool engine = false,
}) async {
  final account = state.scope;
  void requireAccess() {
    if (!(engine ? state.adminAccess : state.publishingAccess) ||
        state.scope != account) {
      throw StateError('Administrator access is off.');
    }
  }

  requireAccess();
  if (!RegExp(r'^[a-z0-9][a-z0-9-]*$').hasMatch(gameId)) {
    throw Exception('Enter a stable game ID first.');
  }
  final kind = target == 'package'
      ? 'package'
      : (target == 'preview' || target == 'streams')
      ? 'video'
      : 'image';
  final file = await openFile(
    acceptedTypeGroups: [
      XTypeGroup(
        label: kind,
        extensions: kind == 'image'
            ? ['png', 'jpg', 'jpeg', 'webp']
            : kind == 'video'
            ? ['mp4']
            : engine
            ? ['zip']
            : ['zip', 'exe', 'apk', 'msi', 'dmg', 'gz'],
      ),
    ],
  );
  if (file == null) return null;
  var length = await file.length(), name = file.name;
  Uint8List? imageBytes;
  var mime = kind == 'video' ? 'video/mp4' : 'application/octet-stream';
  if (kind == 'image') {
    if (length > 20 * 1024 * 1024) throw Exception('Image exceeds 20 MB.');
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Image cannot be decoded.');
    if (!context.mounted) return null;
    double zoom = 1;
    final aspect = decoded.width / decoded.height;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: state,
        builder: (_, _) =>
            (engine ? state.adminAccess : state.publishingAccess) &&
                state.scope == account
            ? StatefulBuilder(
                builder: (context, setLocal) => RyhzeAlertDialog(
                  title: const Text('Crop artwork'),
                  content: SizedBox(
                    width: 320,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 240,
                          child: AspectRatio(
                            aspectRatio: aspect,
                            child: ClipRect(
                              child: Transform.scale(
                                scale: zoom,
                                child: Image.memory(bytes, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ),
                        Slider(
                          value: zoom,
                          min: 1,
                          max: 3,
                          onChanged: (v) => setLocal(() => zoom = v),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Use crop'),
                    ),
                  ],
                ),
              )
            : RyhzeAlertDialog(
                title: const Text('Administrator access is off.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Close'),
                  ),
                ],
              ),
      ),
    );
    if (accepted != true) return null;
    var width = decoded.width.toDouble(), height = width / aspect;
    if (height > decoded.height) {
      height = decoded.height.toDouble();
      width = height * aspect;
    }
    width /= zoom;
    height /= zoom;
    final crop = img.copyCrop(
      decoded,
      x: ((decoded.width - width) / 2).round(),
      y: ((decoded.height - height) / 2).round(),
      width: width.round(),
      height: height.round(),
    );
    imageBytes = Uint8List.fromList(
      img.encodeJpg(
        img.copyResize(crop, width: crop.width.clamp(1, 2560)),
        quality: 90,
      ),
    );
    length = imageBytes.length;
    name = '${name.split('.').first}.jpg';
    mime = 'image/jpeg';
  }
  if (engine && length > (kind == 'package' ? 2 : 4) * 1024 * 1024 * 1024) {
    throw Exception('This engine file is too large.');
  }
  requireAccess();
  final base = engine ? '/api/admin/engine' : '/api/admin/publishing';
  final resumeKey =
      'publishing-upload:${state.scope}:$gameId:$name:$length:${await file.lastModified()}';
  var uploadId = state.prefs.getString(resumeKey);
  requireAccess();
  if (uploadId == null) {
    final r = await state.api.request(
      '$base/uploads/start',
      body: {
        'gameId': gameId,
        'filename': name,
        'bytes': length,
        'mime': mime,
        'kind': kind,
      },
    );
    uploadId = r['id'];
    await state.prefs.setString(resumeKey, uploadId!);
  }
  const partSize = 5 * 1024 * 1024;
  for (int offset = 0, n = 1; offset < length; offset += partSize, n++) {
    final end = (offset + partSize).clamp(0, length);
    final chunk = imageBytes != null
        ? imageBytes.sublist(offset, end)
        : await file.openRead(offset, end).expand((c) => c).toList();
    requireAccess();
    progress('Uploading ${((offset / length) * 100).round()}%');
    final req =
        http.Request(
            'POST',
            state.api.resource('$base/uploads/$uploadId/part?number=$n'),
          )
          ..followRedirects = false
          ..headers.addAll({
            ...state.api.authHeaders,
            'Origin': state.api.origin.origin,
            'Content-Type': 'application/octet-stream',
          })
          ..bodyBytes = chunk;
    final response = await http.Response.fromStream(
      await state.api.client.send(req).timeout(const Duration(minutes: 2)),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Upload interrupted. Select the same file to resume. ${jsonDecode(response.body)['error']}',
      );
    }
  }
  requireAccess();
  progress('Verifying file integrity…');
  final req =
      http.Request(
          'POST',
          state.api.resource('$base/uploads/$uploadId/complete'),
        )
        ..followRedirects = false
        ..headers.addAll({
          ...state.api.authHeaders,
          'Origin': state.api.origin.origin,
          'Content-Type': 'application/json',
        })
        ..body = '{}';
  final response = await http.Response.fromStream(
    await state.api.client.send(req).timeout(const Duration(minutes: 5)),
  );
  final result = jsonDecode(response.body);
  if (response.statusCode != 200) throw Exception(result['error']);
  await state.prefs.remove(resumeKey);
  progress('');
  requireAccess();
  return {...Map<String, dynamic>.from(result), 'title': name};
}
