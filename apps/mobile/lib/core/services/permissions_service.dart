import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/user_roles.dart';
import '../constants/plan_features.dart';
import '../../data/database/database.dart';

/// Role-based permissions for freelancer, client, and admin flows.
class PermissionsService {
  const PermissionsService();

  bool canManageCustomers(User? user) => isFreelancerAccount(user);

  bool canManageInvoices(User? user) => isFreelancerAccount(user);

  bool canViewClientPortal(User? user) => isClientAccount(user);

  bool canAccessAdminConsole(User? user) => isSuperAdmin(user);

  bool canGrantAdmin(User? user) => isSuperAdmin(user);

  bool canUseTeamFeatures(User? user, String plan) => isFreelancerAccount(user);

  bool canExportData(User? user, {String? plan, bool isClient = false}) {
    if (user == null) return false;
    if (isSuperAdmin(user)) return true;
    if (isClient) return PlanFeatures.clientDataExport(plan);
    return PlanFeatures.dataExport(plan);
  }

  bool canDeleteEntity(User? user, {required int ownerUserId}) {
    if (user == null) return false;
    if (isSuperAdmin(user)) return true;
    return user.id == ownerUserId;
  }

  bool canEditProject(User? user, {required int ownerUserId, String teamRole = 'member'}) {
    if (user == null) return false;
    if (user.id == ownerUserId) return true;
    return teamRole == 'editor' || teamRole == 'admin';
  }
}

final permissionsServiceProvider = Provider<PermissionsService>((ref) {
  return const PermissionsService();
});

bool isFreelancerAccount(User? user) {
  if (user == null) return false;
  return user.accountType == kAccountFreelancer || user.accountType == 'user' || user.role == 'admin';
}

bool isClientAccount(User? user) {
  if (user == null) return false;
  return user.accountType == 'client';
}
