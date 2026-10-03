import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/database_provider.dart';
import '../services/cloud_write_guard.dart';
import 'supabase_auth_helper.dart';
import 'supabase_sync_service.dart';

final cloudProjectRepositoryProvider = Provider<CloudProjectRepository>((ref) {
  return CloudProjectRepository(ref);
});

/// Project snapshot shared cross-device via Supabase.
class CloudSharedProject {
  CloudSharedProject({
    required this.shareId,
    required this.freelancerUid,
    required this.freelancerEmail,
    required this.clientEmail,
    required this.projectName,
    required this.description,
    required this.status,
    required this.budget,
    required this.currency,
    required this.priority,
    this.clientUid,
    this.deadline,
    this.updatedAt,
  });

  final String shareId;
  final String freelancerUid;
  final String freelancerEmail;
  final String clientEmail;
  final String? clientUid;
  final String projectName;
  final String description;
  final String status;
  final double budget;
  final String currency;
  final String priority;
  final DateTime? deadline;
  final DateTime? updatedAt;

  factory CloudSharedProject.fromRow(Map<String, dynamic> row) {
    return CloudSharedProject(
      shareId: row['share_id'] as String,
      freelancerUid: row['freelancer_uid'] as String? ?? '',
      freelancerEmail: row['freelancer_email'] as String? ?? '',
      clientEmail: row['client_email'] as String? ?? '',
      clientUid: row['client_uid'] as String?,
      projectName: row['project_name'] as String? ?? 'Project',
      description: row['description'] as String? ?? '',
      status: row['status'] as String? ?? 'not_started',
      budget: (row['budget'] as num?)?.toDouble() ?? 0,
      currency: row['currency'] as String? ?? 'USD',
      priority: row['priority'] as String? ?? 'medium',
      deadline: row['deadline'] != null ? DateTime.tryParse(row['deadline'] as String) : null,
      updatedAt: row['updated_at'] != null ? DateTime.tryParse(row['updated_at'] as String) : null,
    );
  }
}

/// View model for client portal, local project or cloud-only share.
class ClientSharedProjectView {
  const ClientSharedProjectView({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.budget,
    required this.currency,
    required this.deadline,
    required this.isCloudOnly,
    this.localProject,
    this.cloudProject,
  });

  final String id;
  final String name;
  final String description;
  final String status;
  final double budget;
  final String currency;
  final DateTime? deadline;
  final bool isCloudOnly;
  final Project? localProject;
  final CloudSharedProject? cloudProject;
}

class CloudProjectRepository {
  CloudProjectRepository(this.ref);

  final Ref ref;

  SupabaseClient get _db => SupabaseAuthHelper.client;

  String shareIdFor({required String freelancerUid, required int localProjectId}) =>
      '${freelancerUid}_$localProjectId';

  Future<void> shareProject({
    required String freelancerUid,
    required String freelancerEmail,
    required String clientEmail,
    required int localProjectId,
    required Project project,
    String currency = 'USD',
  }) async {
    final shareId = shareIdFor(freelancerUid: freelancerUid, localProjectId: localProjectId);
    final clientUid = await ref.read(supabaseSyncServiceProvider).uidForEmail(clientEmail);
    await _db.from('project_shares').upsert({
      'share_id': shareId,
      'freelancer_uid': freelancerUid,
      'freelancer_email': freelancerEmail.trim().toLowerCase(),
      'client_email': clientEmail.trim().toLowerCase(),
      'client_uid': ?clientUid,
      'local_project_id': localProjectId,
      'project_name': project.name,
      'description': project.description,
      'status': project.status,
      'budget': project.budget,
      'currency': currency,
      'priority': project.priority,
      if (project.deadline != null) 'deadline': project.deadline!.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Stream<List<CloudSharedProject>> watchForClient({required String email, String? uid}) {
    final normalized = email.trim().toLowerCase();
    if (uid == null || uid.isEmpty) {
      return _db
          .from('project_shares')
          .stream(primaryKey: ['share_id'])
          .eq('client_email', normalized)
          .map((rows) => rows.map(CloudSharedProject.fromRow).toList());
    }

    var byUid = <CloudSharedProject>[];
    var byEmail = <CloudSharedProject>[];
    final controller = StreamController<List<CloudSharedProject>>();

    void emit() {
      final merged = <String, CloudSharedProject>{};
      for (final row in [...byUid, ...byEmail]) {
        merged[row.shareId] = row;
      }
      final list = merged.values.toList()
        ..sort((a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(a.updatedAt ?? DateTime(2000)));
      if (!controller.isClosed) {
        controller.add(list);
      }
    }

    final uidSub = _db
        .from('project_shares')
        .stream(primaryKey: ['share_id'])
        .eq('client_uid', uid)
        .listen((rows) {
      byUid = rows.map(CloudSharedProject.fromRow).toList();
      emit();
    }, onError: controller.addError);
    final emailSub = _db
        .from('project_shares')
        .stream(primaryKey: ['share_id'])
        .eq('client_email', normalized)
        .listen((rows) {
      byEmail = rows.map(CloudSharedProject.fromRow).toList();
      emit();
    }, onError: controller.addError);

    controller.onCancel = () {
      uidSub.cancel();
      emailSub.cancel();
    };
    return controller.stream;
  }

  Future<void> shareHybrid({
    required User freelancer,
    required String clientEmail,
    required int localProjectId,
    required Project project,
  }) async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null || uid.isEmpty) {
      debugPrint('Cloud project share skipped: no Supabase session');
      return;
    }
    await ref.read(cloudWriteGuardProvider).runOrEnqueue(
          kind: 'project_share',
          payload: {
            'projectId': localProjectId,
            'clientEmail': clientEmail,
          },
          action: () => shareProject(
                freelancerUid: uid,
                freelancerEmail: freelancer.email,
                clientEmail: clientEmail,
                localProjectId: localProjectId,
                project: project,
                currency: project.currency.isNotEmpty ? project.currency : 'USD',
              ),
        );
  }
}

List<ClientSharedProjectView> mergeClientProjects({
  required List<Project> local,
  required List<CloudSharedProject> cloud,
}) {
  final views = <ClientSharedProjectView>[];
  final matchedShareIds = <String>{};

  for (final p in local) {
    CloudSharedProject? match;
    for (final c in cloud) {
      if (c.shareId.endsWith('_${p.id}') ||
          c.projectName.toLowerCase() == p.name.toLowerCase()) {
        match = c;
        matchedShareIds.add(c.shareId);
        break;
      }
    }
    views.add(
      ClientSharedProjectView(
        id: match != null ? 'cloud_${match.shareId}' : 'local_${p.id}',
        name: p.name,
        description: p.description,
        status: p.status,
        budget: p.budget,
        currency: p.currency.isNotEmpty ? p.currency : (match?.currency ?? 'USD'),
        deadline: p.deadline,
        isCloudOnly: false,
        localProject: p,
        cloudProject: match,
      ),
    );
  }

  for (final c in cloud) {
    if (matchedShareIds.contains(c.shareId)) continue;
    views.add(
      ClientSharedProjectView(
        id: 'cloud_${c.shareId}',
        name: c.projectName,
        description: c.description,
        status: c.status,
        budget: c.budget,
        currency: c.currency.isNotEmpty ? c.currency : 'USD',
        deadline: c.deadline,
        isCloudOnly: true,
        cloudProject: c,
      ),
    );
  }

  views.sort((a, b) => a.name.compareTo(b.name));
  return views;
}

Stream<List<ClientSharedProjectView>> watchUnifiedClientProjects(Ref ref, User user) async* {
  final db = ref.read(databaseProvider);
  final cloudRepo = ref.read(cloudProjectRepositoryProvider);
  var local = <Project>[];
  var cloud = <CloudSharedProject>[];

  final controller = StreamController<List<ClientSharedProjectView>>();
  final localSub = db.watchProjectsForClient(user.id).listen(
    (value) {
      local = value;
      controller.add(mergeClientProjects(local: local, cloud: cloud));
    },
    onError: controller.addError,
  );
  final cloudSub = cloudRepo.watchForClient(email: user.email, uid: SupabaseAuthHelper.currentUid).listen(
    (value) {
      cloud = value;
      controller.add(mergeClientProjects(local: local, cloud: cloud));
    },
    onError: (e) => debugPrint('Cloud projects error: $e'),
  );

  ref.onDispose(() {
    localSub.cancel();
    cloudSub.cancel();
    controller.close();
  });

  yield* controller.stream;
}
