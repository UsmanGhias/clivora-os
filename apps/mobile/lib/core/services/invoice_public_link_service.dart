import 'dart:math';
import '../constants/admin_config.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_invoice_repository.dart';
import '../cloud/supabase_auth_helper.dart';
final invoicePublicLinkServiceProvider = Provider<InvoicePublicLinkService>((ref) {
  return InvoicePublicLinkService(ref);
});

/// Tokenized public invoice links for web guest view (no app install required).
class InvoicePublicLinkService {
  InvoicePublicLinkService(this.ref);
  final Ref ref;

  static String _token() {
    final r = Random.secure();
    final bytes = List<int>.generate(24, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Ensures share has a public_token and returns https://clivora…/i/{token}
  Future<String?> ensurePublicLink(String shareId) async {
    try {
      final row = await SupabaseAuthHelper.client
          .from('invoice_shares')
          .select('public_token')
          .eq('share_id', shareId)
          .maybeSingle();
      var token = row?['public_token'] as String?;
      if (token == null || token.isEmpty) {
        token = _token();
        await SupabaseAuthHelper.client.from('invoice_shares').update({
          'public_token': token,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('share_id', shareId);
      }
      return publicUrlForToken(token);
    } catch (e) {
      debugPrint('Public invoice link failed: $e');
      return null;
    }
  }

  String publicUrlForToken(String token) {
    // Hosted on clivora-web; path handled by Next.js route.
    return '$kClivoraWebBaseUrl/i/$token';
  }

  Future<CloudInvoiceShare?> fetchByToken(String token) async {
    try {
      final row = await SupabaseAuthHelper.client
          .from('invoice_shares')
          .select()
          .eq('public_token', token)
          .maybeSingle();
      if (row == null) return null;
      return CloudInvoiceShare.fromRow(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('Fetch public invoice failed: $e');
      return null;
    }
  }

}
