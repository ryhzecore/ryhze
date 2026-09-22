import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'api.dart';

class Games {
  static Future<String?> riotClient() async {
    if (!Platform.isWindows) return null;
    final base = Platform.environment['PROGRAMDATA'] ?? r'C:\ProgramData';
    try {
      final installs =
          jsonDecode(
                await File(
                  '$base/Riot Games/RiotClientInstalls.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      for (final key in ['rc_default', 'rc_live']) {
        final value = installs[key];
        if (value is String &&
            value.toLowerCase().endsWith('riotclientservices.exe') &&
            await File(value).exists()) {
          return value;
        }
      }
    } catch (_) {
      /* Fall back to the standard Riot installation directory. */
    }
    const standard = r'C:\Riot Games\Riot Client\RiotClientServices.exe';
    return await File(standard).exists() ? standard : null;
  }

  static Future<void> launchValorant(String path) async {
    if (!Platform.isWindows ||
        !path.toLowerCase().endsWith('riotclientservices.exe') ||
        !await File(path).exists()) {
      throw const ApiException(
        'Riot Client could not be found. Install it and try again.',
      );
    }
    await Process.start(path, [
      '--launch-product=valorant',
      '--launch-patchline=live',
    ], mode: ProcessStartMode.detached);
  }

  static Future<File> download(
    RyhzeApi api,
    String path,
    String titleId,
    http.Client client,
    void Function(double?) progress,
  ) async {
    final folder =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final directory = Directory('${folder.path}/Ryhze');
    await directory.create(recursive: true);
    final safeName = titleId.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '');
    final destination = File('${directory.path}/$safeName-installer.exe');
    final partial = File('${destination.path}.part');
    final req = http.Request('GET', api.media(path))..followRedirects = false;
    req.headers.addAll(api.authHeaders);
    final response = await client
        .send(req)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode == 401
            ? 'Sign in again to install this game.'
            : 'This download is not available yet.',
        response.statusCode,
      );
    }
    final sink = partial.openWrite();
    var bytes = 0;
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 45),
      )) {
        sink.add(chunk);
        bytes += chunk.length;
        progress(
          response.contentLength == null
              ? null
              : bytes / response.contentLength!,
        );
      }
      await sink.flush();
      await sink.close();
      if (bytes == 0 ||
          (response.contentLength != null && bytes != response.contentLength)) {
        throw const ApiException(
          'The download was interrupted. Please try again.',
        );
      }
      return await partial.rename(destination.path);
    } catch (_) {
      await sink.close();
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }
}
