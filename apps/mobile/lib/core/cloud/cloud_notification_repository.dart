import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../data/database/database.dart';
import '../services/cloud_write_guard.dart';
import 'cloud_message_repository.dart';
import 'supabase_auth_helper.dart';
import 'supabase_sync_service.dart';

final cloudNotificationRepositoryProvider = Provider<CloudNotificationRepository>((ref) {
  return CloudNotificationRepository(ref);
});

class CloudNotification {
  CloudNotification({
    required this.id,
    required this.userUid,
    required this.title,
    required this.body,
    required this.kind,
    required this.isRead,
    required this.createdAt,
    this.fromUid,
  });

  final String id;
  final String userUid;
  final String? fromUid;
  final String title;
  final String body;
  final String kind;
  final bool isRead;
  final DateTime createdAt;

  factory CloudNotification.fromRow(Map<String, dynamic> row) {
    return CloudNotification(
      id: row['id'] as String,
      userUid: row['user_uid'] as String,
      fromUid: row['from_uid'] as String?,
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      kind: row['kind'] as String? ?? 'info',
      isRead: row['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class CloudNotificationRepository {
  CloudNotificationRepository(this.ref);

  final Ref ref;

  SupabaseClient get _db => SupabaseAuthHelper.client;

  Future<void> send({
    required String toEmail,
    required String title,
    required String body,
    String kind = 'info',
  }) async {
    final fromUid = SupabaseAuthHelper.currentUid;
    if (fromUid == null) return;

    await ref.read(cloudWriteGuardProvider).runOrEnqueue(
          kind: 'notification',
          payload: {
            'toEmail': toEmail,
            'title': title,
            'body': body,
            'kind': kind,
          },
          action: () async {
            final toUid = await ref.read(supabaseSyncServiceProvider).uidForEmail(toEmail);
            if (toUid == null) {
              debugPrint('Notification skipped: no linked profile for $toEmail');
              return;
            }
            await _insertToUid(fromUid: fromUid, toUid: toUid, title: title, body: body, kind: kind);
          },
        );
  }

  Future<void> sendToUid({
    required String toUid,
    required String title,
    required String body,
    String kind = 'info',
  }) async {
    final fromUid = SupabaseAuthHelper.currentUid;
    if (fromUid == null || toUid.isEmpty) return;

    await ref.read(cloudWriteGuardProvider).runOrEnqueue(
          kind: 'notification',
          payload: {
            'toUid': toUid,
            'title': title,
            'body': body,
            'kind': kind,
          },
          action: () => _insertToUid(
                fromUid: fromUid,
                toUid: toUid,
                title: title,
                body: body,
                kind: kind,
              ),
        );
  }

  Future<void> _insertToUid({
    required String fromUid,
    required String toUid,
    required String title,
    required String body,
    required String kind,
  }) async {
    try {
      await _db.from('notifications').insert({
        'user_uid': toUid,
        'from_uid': fromUid,
        'title': title,
        'body': body,
        'kind': kind,
      });
    } catch (e) {
      debugPrint('Notification insert failed: $e');
      rethrow;
    }
  }

  Stream<List<CloudNotification>> watchForUser(String uid) async* {
    try {
      final initial = await _db
          .from('notifications')
          .select()
          .eq('user_uid', uid)
          .order('created_at', ascending: false)
          .limit(100);
      yield (initial as List).map((r) => CloudNotification.fromRow(Map<String, dynamic>.from(r as Map))).toList();
    } catch (e) {
      debugPrint('Notification bootstrap failed: $e');
      yield <CloudNotification>[];
    }
    yield* _db
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_uid', uid)
        .order('created_at', ascending: false)
        .limit(100)
        .map((rows) => rows.map(CloudNotification.fromRow).toList());
  }

  Future<void> markRead(String id) async {
    await _db.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _db.from('notifications').delete().eq('id', id);
  }

  Future<int> countUnread(String uid) async {
    final rows = await _db
        .from('notifications')
        .select('id')
        .eq('user_uid', uid)
        .eq('is_read', false);
    return (rows as List).length;
  }
}

final cloudClientTaskRepositoryProvider = Provider<CloudClientTaskRepository>((ref) {
  return CloudClientTaskRepository(ref);
});

class CloudClientTask {
  CloudClientTask({
    required this.id,
    required this.clientUid,
    required this.freelancerUid,
    required this.title,
    required this.description,
    required this.status,
    required this.isRead,
    required this.createdAt,
    this.projectShareId,
  });

  final String id;
  final String clientUid;
  final String freelancerUid;
  final String? projectShareId;
  final String title;
  final String description;
  final String status;
  final bool isRead;
  final DateTime createdAt;

  factory CloudClientTask.fromRow(Map<String, dynamic> row) {
    return CloudClientTask(
      id: row['id'] as String,
      clientUid: row['client_uid'] as String,
      freelancerUid: row['freelancer_uid'] as String,
      projectShareId: row['project_share_id'] as String?,
      title: row['title'] as String? ?? '',
      description: row['description'] as String? ?? '',
      status: row['status'] as String? ?? 'pending',
      isRead: row['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class CloudClientTaskRepository {
  CloudClientTaskRepository(this.ref);

  final Ref ref;

  SupabaseClient get _db => SupabaseAuthHelper.client;

  Future<void> assignTask({
    required String clientUid,
    required String freelancerUid,
    required String title,
    required String description,
    String? projectShareId,
    User? clientUser,
  }) async {
    try {
      await _db.from('client_tasks').insert({
        'client_uid': clientUid,
        'freelancer_uid': freelancerUid,
        'title': title,
        'description': description,
        'project_share_id': ?projectShareId,
      });
    } catch (e) {
      debugPrint('client_tasks insert failed: $e');
      rethrow;
    }

    final freelancerEmail = await _emailForUid(freelancerUid);
    if (freelancerEmail != null) {
      await ref.read(cloudNotificationRepositoryProvider).sendToUid(
            toUid: freelancerUid,
            title: 'New task from client',
            body: title,
            kind: 'task',
          );

      if (clientUser != null) {
        final taskBody = description.isNotEmpty ? '$title\n\n$description' : title;
        await ref.read(cloudMessageRepositoryProvider).sendHybrid(
              fromUser: clientUser,
              toEmail: freelancerEmail,
              subject: '[Task] $title',
              body: taskBody,
              projectShareId: projectShareId,
            );
      }
    }
  }

  Future<String?> _emailForUid(String uid) async {
    final row = await _db.from('profiles').select('email').eq('id', uid).maybeSingle();
    return row?['email'] as String?;
  }

  Stream<List<CloudClientTask>> watchForFreelancer(String uid) {
    return _db
        .from('client_tasks')
        .stream(primaryKey: ['id'])
        .eq('freelancer_uid', uid)
        .order('created_at', ascending: false)
        .limit(50)
        .map((rows) => rows.map(CloudClientTask.fromRow).toList());
  }

  Stream<List<CloudClientTask>> watchForClient(String uid) {
    return _db
        .from('client_tasks')
        .stream(primaryKey: ['id'])
        .eq('client_uid', uid)
        .order('created_at', ascending: false)
        .limit(50)
        .map((rows) => rows.map(CloudClientTask.fromRow).toList());
  }

  Future<void> markRead(String id) async {
    await _db.from('client_tasks').update({'is_read': true}).eq('id', id);
  }

  Future<void> updateStatus(String id, String status) async {
    await _db.from('client_tasks').update({'status': status, 'is_read': true}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _db.from('client_tasks').delete().eq('id', id);
  }
}
