import 'dart:convert';

/// Encodes contract body + optional attachment path without a DB migration.
class ContractContentHelper {
  static const _metaStart = '---CLIVORA-CONTRACT-META---';
  static const _metaEnd = '---END-META---';
  static const metaStart = _metaStart;

  static String encode({
    required String body,
    String? attachmentPath,
    String? clientSignature,
    String? signedAt,
    String? deviceMeta,
  }) {
    final meta = <String, String>{
      if (attachmentPath != null && attachmentPath.isNotEmpty) 'attachment': attachmentPath,
      if (clientSignature != null && clientSignature.isNotEmpty) 'clientSignature': clientSignature,
      if (signedAt != null && signedAt.isNotEmpty) 'signedAt': signedAt,
      if (deviceMeta != null && deviceMeta.isNotEmpty) 'deviceMeta': deviceMeta,
    };
    if (meta.isEmpty) return body.trim();
    return '$_metaStart${jsonEncode(meta)}$_metaEnd\n${body.trim()}';
  }

  static ({
    String body,
    String? attachmentPath,
    String? clientSignature,
    String? signedAt,
    String? deviceMeta,
  }) decode(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith(_metaStart)) {
      return (
        body: trimmed,
        attachmentPath: null,
        clientSignature: null,
        signedAt: null,
        deviceMeta: null,
      );
    }
    final end = trimmed.indexOf(_metaEnd);
    if (end < 0) {
      return (
        body: trimmed,
        attachmentPath: null,
        clientSignature: null,
        signedAt: null,
        deviceMeta: null,
      );
    }
    final jsonPart = trimmed.substring(_metaStart.length, end);
    final body = trimmed.substring(end + _metaEnd.length).trimLeft();
    try {
      final map = jsonDecode(jsonPart) as Map<String, dynamic>;
      return (
        body: body,
        attachmentPath: map['attachment'] as String?,
        clientSignature: map['clientSignature'] as String?,
        signedAt: map['signedAt'] as String?,
        deviceMeta: map['deviceMeta'] as String?,
      );
    } catch (_) {
      return (
        body: body,
        attachmentPath: null,
        clientSignature: null,
        signedAt: null,
        deviceMeta: null,
      );
    }
  }
}
