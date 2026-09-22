import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The agreement ryhze.com is serving right now, exactly as served.
///
/// The website only offers a document once it is finished (no placeholders,
/// an effective date, no draft banner), so an agreement that parses here is
/// one that is in force. The text is verified against its SHA-256 and that
/// hash is what the account accepts; any change to the wording is a new
/// hash and must be accepted again.
class Agreement {
  final String key, id, title, text, digest, url;
  final String? revision, effectiveDate;
  const Agreement._({
    required this.key,
    required this.id,
    required this.title,
    required this.text,
    required this.digest,
    required this.url,
    this.revision,
    this.effectiveDate,
  });

  static Agreement? parse(dynamic value) {
    if (value is! Map) return null;
    final key = value['key'],
        id = value['id'],
        title = value['title'],
        text = value['text'],
        digest = value['sha256'],
        url = value['url'];
    if (key is! String ||
        !RegExp(r'^[a-z][a-z-]{1,40}$').hasMatch(key) ||
        id is! String ||
        !RegExp(r'^[A-Z][A-Z0-9.-]{2,64}$').hasMatch(id) ||
        title is! String ||
        title.trim().isEmpty ||
        title.length > 200 ||
        text is! String ||
        text.trim().isEmpty ||
        text.length > 512 * 1024 ||
        digest is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest) ||
        sha256.convert(utf8.encode(text)).toString() != digest ||
        url is! String ||
        !url.startsWith('https://')) {
      return null;
    }
    return Agreement._(
      key: key,
      id: id,
      title: title.trim(),
      text: text,
      digest: digest,
      url: url,
      revision: value['revision'] is String ? value['revision'] : null,
      effectiveDate: value['effectiveDate'] is String
          ? value['effectiveDate']
          : null,
    );
  }
}

/// Which agreement texts an account has accepted on this device.
///
/// Stored per account scope so a second person signing in on the same device
/// is asked in their own right. Only the identity of the text is kept: the
/// agreement id, its hash and the time. No project content, hardware or
/// network identifiers.
class AgreementRecords {
  final SharedPreferences prefs;
  const AgreementRecords(this.prefs);

  String _key(String scope) => 'agreement-accepted:$scope';

  List<Map<String, dynamic>> _entries(String scope) {
    final raw = prefs.getString(_key(scope));
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  bool accepted(String scope, Agreement agreement) => _entries(
    scope,
  ).any((e) => e['id'] == agreement.id && e['sha256'] == agreement.digest);

  Future<void> record(String scope, Agreement agreement) async {
    final entries = _entries(scope)
      ..removeWhere((e) => e['id'] == agreement.id)
      ..add({
        'id': agreement.id,
        'sha256': agreement.digest,
        'acceptedAt': DateTime.now().toUtc().toIso8601String(),
      });
    await prefs.setString(_key(scope), jsonEncode(entries));
  }
}
