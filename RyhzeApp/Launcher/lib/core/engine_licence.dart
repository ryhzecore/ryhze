import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Exact release-supplied agreement and notices; never substitute generic terms.
class EngineLicence {
  final String text, digest;
  const EngineLicence._(this.text, this.digest);

  static EngineLicence? parse(dynamic value) {
    if (value is! Map) return null;
    final text = value['text'];
    final digest = value['sha256'];
    if (text is! String ||
        text.trim().isEmpty ||
        text.length > 512 * 1024 ||
        digest is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest) ||
        sha256.convert(utf8.encode(text)).toString() != digest) {
      return null;
    }
    return EngineLicence._(text, digest);
  }

  Map<String, String> toJson() => {'text': text, 'sha256': digest};
}
