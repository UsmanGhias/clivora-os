import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/admin_config.dart';
import 'supabase_auth_helper.dart';

final adminCloudRepositoryProvider = Provider<AdminCloudRepository>((ref) {
  return AdminCloudRepository(ref);
});

class CloudProfileRow {
  CloudProfileRow({
    required this.id,
    required this.email,
    required this.name,
    required this.accountType,
    required this.role,
    required this.updatedAt,
  });

  final String id;
  final String email;
  final String name;
  final String accountType;
  final String role;
  final DateTime? updatedAt;

  factory CloudProfileRow.fromRow(Map<String, dynamic> row) {
    return CloudProfileRow(
      id: row['id'] as String,
      email: row['email'] as String? ?? '',
      name: row['name'] as String? ?? '',
      accountType: row['account_type'] as String? ?? 'freelancer',
      role: row['role'] as String? ?? 'user',
      updatedAt: row['updated_at'] != null ? DateTime.tryParse(row['updated_at'] as String) : null,
    );
  }

  String get typeLabel {
    if (role == 'admin' && accountType == 'client') return 'Client (Admin)';
    if (role == 'admin' && (accountType == 'freelancer' || accountType == 'user')) {
      return 'Freelancer (Admin)';
    }
    if (accountType == 'admin' || role == 'admin') return 'Admin';
    if (accountType == 'client') return 'Client';
    return 'Freelancer';
  }
}

class AdminActivityItem {
  AdminActivityItem({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.createdAt,
  });

  final String kind;
  final String title;
  final String subtitle;
  final DateTime createdAt;
}

class AdminCloudRepository {
  AdminCloudRepository(this.ref);

  final Ref ref;

  SupabaseClient get _db => SupabaseAuthHelper.client;

  Future<List<CloudProfileRow>> fetchAllProfiles() async {
    final rows = await _db
        .from('profiles')
        .select('id,email,name,account_type,role,updated_at')
        .order('updated_at', ascending: false)
        .limit(500);
    return (rows as List).map((r) => CloudProfileRow.fromRow(r as Map<String, dynamic>)).toList();
  }

  Future<List<AdminActivityItem>> fetchRecentActivity() async {
    final items = <AdminActivityItem>[];

    final events = await _db
        .from('clivora_events')
        .select('event_type,user_email,user_name,created_at')
        .order('created_at', ascending: false)
        .limit(40);
    for (final row in events as List) {
      final m = row as Map<String, dynamic>;
      items.add(AdminActivityItem(
        kind: 'event',
        title: (m['event_type'] as String? ?? 'event').replaceAll('_', ' ').toUpperCase(),
        subtitle: m['user_email'] as String? ?? m['user_name'] as String? ?? '',
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      ));
    }

    final messages = await _db
        .from('client_messages')
        .select('subject,from_email,to_email,created_at')
        .order('created_at', ascending: false)
        .limit(25);
    for (final row in messages as List) {
      final m = row as Map<String, dynamic>;
      items.add(AdminActivityItem(
        kind: 'message',
        title: m['subject'] as String? ?? 'Message',
        subtitle: '${m['from_email']} → ${m['to_email']}',
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      ));
    }

    final shares = await _db
        .from('project_shares')
        .select('project_name,freelancer_email,client_email,updated_at')
        .order('updated_at', ascending: false)
        .limit(25);
    for (final row in shares as List) {
      final m = row as Map<String, dynamic>;
      items.add(AdminActivityItem(
        kind: 'share',
        title: m['project_name'] as String? ?? 'Project',
        subtitle: '${m['freelancer_email']} → ${m['client_email']}',
        createdAt: DateTime.tryParse(m['updated_at'] as String? ?? '') ?? DateTime.now(),
      ));
    }

    final tasks = await _db
        .from('client_tasks')
        .select('title,status,created_at')
        .order('created_at', ascending: false)
        .limit(25);
    for (final row in tasks as List) {
      final m = row as Map<String, dynamic>;
      items.add(AdminActivityItem(
        kind: 'task',
        title: m['title'] as String? ?? 'Task',
        subtitle: m['status'] as String? ?? 'pending',
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      ));
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items.take(80).toList();
  }

  Future<String?> sendPasswordReset(String email) async {
    final normalized = email.trim().toLowerCase();
    if (!normalized.contains('@')) return 'Invalid email';
    try {
      await _db.auth.resetPasswordForEmail(
        normalized,
        redirectTo: kPasswordResetRedirectUrl,
      );
      return null;
    } catch (e) {
      return 'Reset email failed: $e';
    }
  }
}

final adminCloudProfilesProvider = FutureProvider<List<CloudProfileRow>>((ref) async {
  return ref.read(adminCloudRepositoryProvider).fetchAllProfiles();
});

final adminCloudActivityProvider = FutureProvider<List<AdminActivityItem>>((ref) async {
  return ref.read(adminCloudRepositoryProvider).fetchRecentActivity();
});
