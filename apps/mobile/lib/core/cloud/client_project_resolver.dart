import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/database_provider.dart';
import '../cloud/cloud_project_repository.dart';
import '../cloud/supabase_sync_service.dart';

/// Resolves freelancer Supabase UID for a client project view.
Future<String?> resolveFreelancerUidForClientProject({
  required WidgetRef ref,
  required ClientSharedProjectView project,
  required int clientUserId,
}) async {
  final cloudUid = project.cloudProject?.freelancerUid;
  if (cloudUid != null && cloudUid.isNotEmpty) return cloudUid;

  final local = project.localProject;
  if (local != null) {
    final freelancer = await ref.read(databaseProvider).getFreelancerUserForClientProject(
          clientUserId,
          local.id,
        );
    if (freelancer?.googleId != null && freelancer!.googleId!.isNotEmpty) {
      return freelancer.googleId;
    }
    if (freelancer != null) {
      return ref.read(supabaseSyncServiceProvider).uidForEmail(freelancer.email);
    }
  }

  final shareId = project.cloudProject?.shareId;
  if (shareId != null && shareId.contains('_')) {
    final prefix = shareId.split('_').first;
    if (prefix.isNotEmpty) return prefix;
  }

  return null;
}

String? shareIdForClientProject(ClientSharedProjectView project) {
  return project.cloudProject?.shareId;
}
