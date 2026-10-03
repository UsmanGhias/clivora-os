import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/supabase_auth_helper.dart';

final chatBlockServiceProvider = Provider<ChatBlockService>((ref) => ChatBlockService());

/// Per-contact chat block/unblock (FR-042).
class ChatBlockService {
  SupabaseClient get _db => SupabaseAuthHelper.client;

  Future<bool> isBlocked({required String blockerUid, required String blockedUid}) async {
    if (blockerUid.isEmpty || blockedUid.isEmpty) return false;
    try {
      final row = await _db
          .from('chat_blocks')
          .select('id')
          .eq('blocker_uid', blockerUid)
          .eq('blocked_uid', blockedUid)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  /// True if either side has blocked the other.
  Future<bool> isEitherBlocked(String a, String b) async {
    if (a.isEmpty || b.isEmpty) return false;
    try {
      final rows = await _db
          .from('chat_blocks')
          .select('id')
          .or('and(blocker_uid.eq.$a,blocked_uid.eq.$b),and(blocker_uid.eq.$b,blocked_uid.eq.$a)');
      return (rows as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> block({required String blockerUid, required String blockedUid}) async {
    await _db.from('chat_blocks').upsert({
      'blocker_uid': blockerUid,
      'blocked_uid': blockedUid,
    }, onConflict: 'blocker_uid,blocked_uid');
  }

  Future<void> unblock({required String blockerUid, required String blockedUid}) async {
    await _db
        .from('chat_blocks')
        .delete()
        .eq('blocker_uid', blockerUid)
        .eq('blocked_uid', blockedUid);
  }

  Future<List<String>> blockedUids(String blockerUid) async {
    final rows = await _db.from('chat_blocks').select('blocked_uid').eq('blocker_uid', blockerUid);
    return (rows as List).map((r) => r['blocked_uid'] as String).toList();
  }
}
