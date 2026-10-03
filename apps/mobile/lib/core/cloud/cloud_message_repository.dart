import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/database_provider.dart';
import '../services/chat_block_service.dart';
import 'cloud_notification_repository.dart';
import 'supabase_auth_helper.dart';
import 'supabase_sync_service.dart';

final cloudMessageRepositoryProvider = Provider<CloudMessageRepository>((ref) {
  return CloudMessageRepository(ref);
});

/// Cross-device inbox, stored in Supabase Postgres.
class CloudMessage {
  CloudMessage({
    required this.id,
    required this.fromUid,
    required this.fromEmail,
    required this.toEmail,
    required this.subject,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.toUid,
    this.projectShareId,
  });

  final String id;
  final String fromUid;
  final String? toUid;
  final String fromEmail;
  final String toEmail;
  final String subject;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? projectShareId;

  factory CloudMessage.fromRow(Map<String, dynamic> row) {
    return CloudMessage(
      id: row['id'] as String,
      fromUid: row['from_uid'] as String? ?? '',
      toUid: row['to_uid'] as String?,
      fromEmail: row['from_email'] as String? ?? '',
      toEmail: row['to_email'] as String? ?? '',
      subject: row['subject'] as String? ?? '',
      body: row['body'] as String? ?? '',
      isRead: row['is_read'] as bool? ?? false,
      projectShareId: row['project_share_id'] as String?,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Unified inbox row for client UI (local SQLite + Supabase).
class ClientInboxEntry {
  const ClientInboxEntry({
    required this.id,
    required this.isCloud,
    required this.subject,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.localMessageId,
    this.cloudMessageId,
  });

  final String id;
  final bool isCloud;
  final String subject;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final int? localMessageId;
  final String? cloudMessageId;
}

class CloudMessageRepository {
  CloudMessageRepository(this.ref);

  final Ref ref;

  SupabaseClient get _db => SupabaseAuthHelper.client;

  Future<void> sendMessage({
    required String fromUid,
    required String fromEmail,
    required String toEmail,
    String? toUid,
    required String subject,
    required String body,
    String? projectShareId,
  }) async {
    var resolvedToUid = toUid;
    if (resolvedToUid == null || resolvedToUid.isEmpty) {
      resolvedToUid = await ref.read(supabaseSyncServiceProvider).uidForEmail(toEmail);
    }

    if (resolvedToUid != null && resolvedToUid.isNotEmpty) {
      final blocked = await ref.read(chatBlockServiceProvider).isEitherBlocked(fromUid, resolvedToUid);
      if (blocked) {
        debugPrint('Message blocked: chat_block between $fromUid and $resolvedToUid');
        throw StateError('Messaging is blocked with this contact');
      }
    }

    await _db.from('client_messages').insert({
      'from_uid': fromUid,
      'from_email': fromEmail.trim().toLowerCase(),
      'to_email': toEmail.trim().toLowerCase(),
      if (resolvedToUid != null && resolvedToUid.isNotEmpty) 'to_uid': resolvedToUid,
      'subject': subject,
      'body': body,
      'is_read': false,
      'project_share_id': ?projectShareId,
    });

    if (resolvedToUid != null && resolvedToUid.isNotEmpty) {
      final preview = subject.trim().isNotEmpty
          ? subject.trim()
          : (body.length > 80 ? '${body.substring(0, 80)}…' : body);
      try {
        await ref.read(cloudNotificationRepositoryProvider).sendToUid(
              toUid: resolvedToUid,
              title: 'New message',
              body: preview,
              kind: 'message',
            );
      } catch (e) {
        debugPrint('Message notification failed: $e');
      }
    }
  }

  Stream<List<CloudMessage>> watchClientMailbox({required String uid, required String email}) {
    var sent = <CloudMessage>[];
    var received = <CloudMessage>[];

    final controller = StreamController<List<CloudMessage>>();
    // Never leave UI in perpetual loading, emit immediately, then bootstrap + realtime.
    controller.add(const <CloudMessage>[]);

    Future<void> bootstrap() async {
      try {
        final rows = await _db
            .from('client_messages')
            .select()
            .or('from_uid.eq.$uid,to_uid.eq.$uid')
            .order('created_at', ascending: false)
            .limit(200);
        final all = (rows as List)
            .map((r) => CloudMessage.fromRow(Map<String, dynamic>.from(r as Map)))
            .toList();
        sent = all.where((m) => m.fromUid == uid).toList();
        received = all.where((m) => m.toUid == uid).toList();
        if (!controller.isClosed) controller.add(_mergeMailbox(sent, received));
      } catch (e) {
        debugPrint('Mailbox bootstrap failed: $e');
        if (!controller.isClosed) controller.add(const <CloudMessage>[]);
      }
    }

    unawaited(bootstrap());

    final sentSub = _db
        .from('client_messages')
        .stream(primaryKey: ['id'])
        .eq('from_uid', uid)
        .listen((rows) {
      sent = rows.map(CloudMessage.fromRow).toList();
      if (!controller.isClosed) controller.add(_mergeMailbox(sent, received));
    }, onError: (e) {
      debugPrint('Sent mailbox stream error: $e');
      if (!controller.isClosed) controller.add(_mergeMailbox(sent, received));
    });
    final recvSub = _db
        .from('client_messages')
        .stream(primaryKey: ['id'])
        .eq('to_uid', uid)
        .listen((rows) {
      received = rows.map(CloudMessage.fromRow).toList();
      if (!controller.isClosed) controller.add(_mergeMailbox(sent, received));
    }, onError: (e) {
      debugPrint('Client mailbox error: $e');
      if (!controller.isClosed) controller.add(_mergeMailbox(sent, received));
    });

    controller.onCancel = () {
      sentSub.cancel();
      recvSub.cancel();
    };
    return controller.stream;
  }

  /// All messages in a thread with one contact (chronological).
  Stream<List<CloudMessage>> watchThread({
    required String myUid,
    required String myEmail,
    required String peerEmail,
  }) async* {
    final peer = peerEmail.trim().toLowerCase();
    final me = myEmail.trim().toLowerCase();
    await for (final all in watchClientMailbox(uid: myUid, email: myEmail)) {
      final thread = all.where((m) {
        final to = m.toEmail.trim().toLowerCase();
        final from = m.fromEmail.trim().toLowerCase();
        return (from == me && to == peer) || (from == peer && to == me);
      }).toList();
      thread.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      yield thread;
    }
  }

  Future<void> markMessageReadById(String messageId) async {
    await _db.from('client_messages').update({'is_read': true}).eq('id', messageId);
  }

  Stream<List<CloudMessage>> watchFreelancerMailbox({required String uid}) {
    return watchClientMailbox(uid: uid, email: '');
  }

  List<CloudMessage> _mergeMailbox(List<CloudMessage> sent, List<CloudMessage> received) {
    final map = <String, CloudMessage>{};
    for (final m in [...sent, ...received]) {
      map[m.id] = m;
    }
    final list = map.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Stream<List<CloudMessage>> watchInbox({required String email, String? uid}) {
    final normalized = email.trim().toLowerCase();
    if (uid != null && uid.isNotEmpty) {
      return _db
          .from('client_messages')
          .stream(primaryKey: ['id'])
          .eq('to_uid', uid)
          .order('created_at', ascending: false)
          .limit(100)
          .map((rows) => rows.map(CloudMessage.fromRow).toList());
    }
    return _db
        .from('client_messages')
        .stream(primaryKey: ['id'])
        .eq('to_email', normalized)
        .order('created_at', ascending: false)
        .limit(100)
        .map((rows) => rows.map(CloudMessage.fromRow).toList());
  }

  Future<void> sendHybrid({
    required User fromUser,
    required String toEmail,
    required String subject,
    required String body,
    int? localToUserId,
    int? localProjectId,
    String? projectShareId,
  }) async {
    final fromUid = SupabaseAuthHelper.currentUid;
    final appDb = ref.read(databaseProvider);

    if (fromUid == null || fromUid.isEmpty) {
      debugPrint('Cloud message skipped: no Supabase session (sign in with email or Google)');
      if (localToUserId != null) {
        await appDb.sendClientMessage(
              fromUserId: fromUser.id,
              toUserId: localToUserId,
              subject: subject,
              body: body,
              projectId: localProjectId,
            );
      }
      return;
    }

    try {
      final toUid = await ref.read(supabaseSyncServiceProvider).uidForEmail(toEmail);
      if (toUid != null && toUid.isNotEmpty) {
        final blocked = await ref.read(chatBlockServiceProvider).isEitherBlocked(fromUid, toUid);
        if (blocked) {
          debugPrint('Hybrid message blocked: chat_block between $fromUid and $toUid');
          return;
        }
      }
      await sendMessage(
            fromUid: fromUid,
            fromEmail: fromUser.email,
            toEmail: toEmail,
            toUid: toUid,
            subject: subject,
            body: body,
            projectShareId: projectShareId,
          );
    } catch (e) {
      debugPrint('Hybrid cloud message failed: $e');
    }

    if (localToUserId != null) {
      await appDb.sendClientMessage(
            fromUserId: fromUser.id,
            toUserId: localToUserId,
            subject: subject,
            body: body,
            projectId: localProjectId,
          );
    }
  }
}

List<ClientInboxEntry> mergeInboxEntries({
  required List<ClientMessage> local,
  required List<CloudMessage> cloud,
}) {
  final entries = <ClientInboxEntry>[
    ...local.map(
      (m) => ClientInboxEntry(
        id: 'local_${m.id}',
        isCloud: false,
        subject: m.subject,
        body: m.body,
        isRead: m.isRead,
        createdAt: m.createdAt,
        localMessageId: m.id,
      ),
    ),
    ...cloud.map(
      (m) => ClientInboxEntry(
        id: 'cloud_${m.id}',
        isCloud: true,
        subject: m.subject,
        body: m.body,
        isRead: m.isRead,
        createdAt: m.createdAt,
        cloudMessageId: m.id,
      ),
    ),
  ];
  entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return entries;
}

Stream<List<ClientInboxEntry>> watchUnifiedClientInbox(Ref ref, User user) async* {
  final db = ref.read(databaseProvider);
  final cloudRepo = ref.read(cloudMessageRepositoryProvider);
  var local = <ClientMessage>[];
  var cloud = <CloudMessage>[];

  final controller = StreamController<List<ClientInboxEntry>>();
  final localSub = db.watchInboxForUser(user.id).listen(
    (value) {
      local = value;
      controller.add(mergeInboxEntries(local: local, cloud: cloud));
    },
    onError: controller.addError,
  );
  final cloudSub = cloudRepo.watchInbox(email: user.email, uid: SupabaseAuthHelper.currentUid).listen(
    (value) {
      cloud = value;
      controller.add(mergeInboxEntries(local: local, cloud: cloud));
    },
    onError: (e) => debugPrint('Cloud inbox error: $e'),
  );

  ref.onDispose(() {
    localSub.cancel();
    cloudSub.cancel();
    controller.close();
  });

  yield* controller.stream;
}

Future<void> markInboxEntryRead(WidgetRef ref, ClientInboxEntry entry) async {
  if (entry.localMessageId != null) {
    await ref.read(databaseProvider).markMessageRead(entry.localMessageId!);
  }
  if (entry.cloudMessageId != null) {
    await SupabaseAuthHelper.client
        .from('client_messages')
        .update({'is_read': true})
        .eq('id', entry.cloudMessageId!);
  }
}
