import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/app_providers.dart';
import '../services/admin_management_service.dart';

/// Last sync failure message for user-visible retry prompts.
final syncFailureMessageProvider = StateProvider<String?>((ref) => null);

/// Refresh counts and dashboard after CRM changes. Stream list providers auto-update from Drift.
void invalidateCrmData(WidgetRef ref, {bool customers = false, bool projects = false, bool invoices = false}) {
  if (customers) {
    ref.invalidate(customerCountProvider);
  }
  if (projects) {
    ref.invalidate(projectCountProvider);
    ref.invalidate(projectStatsProvider);
  }
  if (invoices) {
    ref.invalidate(invoiceStatsProvider);
    ref.invalidate(monthlyInvoiceCountProvider);
  }
  ref.invalidate(dashboardStatsProvider);
}

/// Invalidate data providers after reconnect so lists reflect cloud reconciliation.
void invalidateOnReconnect(WidgetRef ref) {
  ref.invalidate(customersProvider);
  ref.invalidate(projectsProvider);
  ref.invalidate(invoicesProvider);
  ref.invalidate(tasksProvider);
  ref.invalidate(dashboardStatsProvider);
  ref.invalidate(invoiceStatsProvider);
  ref.invalidate(projectStatsProvider);
  ref.invalidate(monthlyInvoiceCountProvider);
  ref.invalidate(customerCountProvider);
  ref.invalidate(projectCountProvider);
  ref.invalidate(clientContractsProvider);
  ref.invalidate(clientCloudInvoicesProvider);
  ref.invalidate(clientInvoicesProvider);
  ref.invalidate(unifiedClientInboxProvider);
  ref.invalidate(freelancerMailboxProvider);
  ref.invalidate(unreadMessagesProvider);
  ref.invalidate(cloudNotificationsProvider);
  ref.invalidate(cloudUnreadCountProvider);
  ref.invalidate(freelancerClientTasksProvider);
  ref.invalidate(clientAssignedTasksProvider);
  ref.invalidate(reportsProvider);
}
