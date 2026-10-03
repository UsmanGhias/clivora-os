import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../data/database/database.dart';
import '../auth/auth_service.dart';
import 'cloud_notification_repository.dart';
import 'supabase_auth_helper.dart';

final cloudQuoteRepositoryProvider = Provider<CloudQuoteRepository>((ref) {
  return CloudQuoteRepository(ref);
});

class CloudQuoteShare {
  CloudQuoteShare({
    required this.shareId,
    required this.freelancerUid,
    required this.clientEmail,
    required this.quoteNumber,
    required this.status,
    required this.total,
    required this.currency,
    required this.subtotal,
    required this.taxRate,
    required this.discount,
    required this.lineItems,
    this.localQuoteId = 0,
    this.validUntil,
    this.issueDate,
    this.updatedAt,
  });

  final String shareId;
  final String freelancerUid;
  final String clientEmail;
  final int localQuoteId;
  final String quoteNumber;
  final String status;
  final double total;
  final double subtotal;
  final double taxRate;
  final double discount;
  final String currency;
  final String lineItems;
  final DateTime? validUntil;
  final DateTime? issueDate;
  final DateTime? updatedAt;

  factory CloudQuoteShare.fromRow(Map<String, dynamic> row) {
    return CloudQuoteShare(
      shareId: row['share_id'] as String,
      freelancerUid: row['freelancer_uid'] as String? ?? '',
      clientEmail: row['client_email'] as String? ?? '',
      localQuoteId: (row['local_quote_id'] as num?)?.toInt() ?? 0,
      quoteNumber: row['quote_number'] as String? ?? '',
      status: row['status'] as String? ?? 'sent',
      total: (row['total'] as num?)?.toDouble() ?? 0,
      subtotal: (row['subtotal'] as num?)?.toDouble() ?? 0,
      taxRate: (row['tax_rate'] as num?)?.toDouble() ?? 0,
      discount: (row['discount'] as num?)?.toDouble() ?? 0,
      currency: row['currency'] as String? ?? 'USD',
      lineItems: row['line_items'] as String? ?? '[]',
      validUntil: row['valid_until'] != null ? DateTime.tryParse(row['valid_until'] as String) : null,
      issueDate: row['issue_date'] != null ? DateTime.tryParse(row['issue_date'] as String) : null,
      updatedAt: row['updated_at'] != null ? DateTime.tryParse(row['updated_at'] as String) : null,
    );
  }
}

class CloudQuoteRepository {
  CloudQuoteRepository(this.ref);
  final Ref ref;

  SupabaseClient get _db => SupabaseAuthHelper.client;

  String shareIdFor({required String freelancerUid, required int localQuoteId}) =>
      'quote_${freelancerUid}_$localQuoteId';

  Future<void> syncQuoteToClient({
    required User freelancer,
    required Quote quote,
    required String clientEmail,
    String? clientUid,
  }) async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null || uid.isEmpty) return;
    if (quote.status == 'draft') return;

    final shareId = shareIdFor(freelancerUid: uid, localQuoteId: quote.id);
    try {
      await _db.from('quote_shares').upsert({
        'share_id': shareId,
        'freelancer_uid': uid,
        'freelancer_email': freelancer.email.trim().toLowerCase(),
        'client_email': clientEmail.trim().toLowerCase(),
        'client_uid': ?clientUid,
        'local_quote_id': quote.id,
        'quote_number': quote.quoteNumber,
        'status': quote.status,
        'subtotal': quote.subtotal,
        'tax_rate': quote.taxRate,
        'discount': quote.discount,
        'total': quote.total,
        'currency': quote.currency,
        'line_items': quote.lineItems,
        'issue_date': quote.issueDate.toUtc().toIso8601String(),
        if (quote.validUntil != null) 'valid_until': quote.validUntil!.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (quote.status == 'sent') {
        await ref.read(cloudNotificationRepositoryProvider).send(
              toEmail: clientEmail,
              title: 'Quote ${quote.quoteNumber}',
              body:
                  'You have a new quote for ${quote.currency} ${quote.total.toStringAsFixed(2)}. Open Quotes to accept or decline.',
              kind: 'quote',
            );
      }
    } catch (e) {
      debugPrint('Quote share sync failed (create quote_shares table if missing): $e');
    }
  }

  Future<List<CloudQuoteShare>> fetchForClient({required String email, String? uid}) async {
    try {
      final List rows;
      if (uid != null && uid.isNotEmpty) {
        rows = await _db
            .from('quote_shares')
            .select()
            .eq('client_uid', uid)
            .order('updated_at', ascending: false);
      } else {
        rows = await _db
            .from('quote_shares')
            .select()
            .eq('client_email', email.trim().toLowerCase())
            .order('updated_at', ascending: false);
      }
      return rows
          .map((r) => CloudQuoteShare.fromRow(Map<String, dynamic>.from(r as Map)))
          .where((q) => q.status != 'draft')
          .toList();
    } catch (e) {
      debugPrint('Quote fetch failed: $e');
      return [];
    }
  }

  Future<void> respondToQuote({required String shareId, required bool accept}) async {
    final status = accept ? 'accepted' : 'declined';
    await _db.from('quote_shares').update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('share_id', shareId);

    final row = await _db.from('quote_shares').select().eq('share_id', shareId).maybeSingle();
    if (row == null) return;
    final freelancerUid = row['freelancer_uid'] as String? ?? '';
    final quoteNumber = row['quote_number'] as String? ?? '';
    final profile = await _db.from('profiles').select('email').eq('id', freelancerUid).maybeSingle();
    final email = profile?['email'] as String?;
    if (email != null) {
      final client = ref.read(authStateProvider).valueOrNull;
      await ref.read(cloudNotificationRepositoryProvider).send(
            toEmail: email,
            title: accept ? 'Quote accepted: $quoteNumber' : 'Quote declined: $quoteNumber',
            body: '${client?.name ?? 'Client'} ${accept ? 'accepted' : 'declined'} quote $quoteNumber.',
            kind: 'quote',
          );
    }
  }
}

final clientQuotesProvider = FutureProvider<List<CloudQuoteShare>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final uid = SupabaseAuthHelper.currentUid;
  return ref.read(cloudQuoteRepositoryProvider).fetchForClient(email: user.email, uid: uid);
});
