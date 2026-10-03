import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/supabase_auth_helper.dart';

/// Upload chat images to Supabase Storage (free feature for all plans).
class ChatAttachmentService {
  static const bucket = 'chat-attachments';

  static SupabaseClient get _client => SupabaseAuthHelper.client;

  /// Returns a URL suitable for embedding in chat messages.
  static Future<String> uploadImage({
    required Uint8List bytes,
    required String uid,
    String contentType = 'image/jpeg',
  }) async {
    final ext = contentType.contains('png') ? 'png' : 'jpg';
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    // Short-lived signed URL only (bucket is private; never use getPublicUrl).
    try {
      return await _client.storage.from(bucket).createSignedUrl(path, 60 * 60);
    } catch (e) {
      debugPrint('Chat attachment signed URL failed: $e');
      throw StateError('Could not create secure attachment link. Try again when online.');
    }
  }

  /// Wrap image URL for chat body storage.
  static String imageBody(String url) => '[[img]]$url[[/img]]';

  static bool isImageBody(String body) => body.startsWith('[[img]]') && body.contains('[[/img]]');

  static String imageUrlFromBody(String body) =>
      body.replaceFirst('[[img]]', '').replaceFirst('[[/img]]', '');
}
