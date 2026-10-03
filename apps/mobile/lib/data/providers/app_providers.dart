import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/user_roles.dart';
import '../../core/cloud/cloud_message_repository.dart';
import 'dart:async';

import '../../features/client/client_contract_view.dart';
import '../../core/cloud/cloud_invoice_repository.dart';
import '../../core/cloud/cloud_project_repository.dart';
import '../../core/cloud/supabase_auth_helper.dart';
import '../../core/services/admin_management_service.dart';
import '../../core/services/client_pdf_quota_service.dart';
import '../../core/constants/plan_limits.dart';
import '../../core/constants/plan_features.dart';
import '../../core/utils/duration_formatter.dart';
import '../database/database.dart';
import '../database/user_scoped_queries.dart';
import 'database_provider.dart';
export 'chat_providers.dart';
export 'database_provider.dart';

int? _ownerId(Ref ref) => ref.watch(authStateProvider).valueOrNull?.id;

final businessProfileProvider = StreamProvider<BusinessProfile>((ref) {
  final userId = _ownerId(ref);
  if (userId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchBusinessProfileForUser(userId);
});

final invoiceBrandingProvider = StreamProvider<InvoiceBranding>((ref) {
  final userId = _ownerId(ref);
  if (userId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchInvoiceBrandingForUser(userId);
});

final appSettingsProvider = StreamProvider<AppSettingsTableData>((ref) {
  final userId = _ownerId(ref);
  if (userId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchAppSettingsForUser(userId);
});

final clientProjectsProvider = StreamProvider<List<Project>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchProjectsForClient(user.id);
});

/// Client portal, merges local SQLite links + Supabase cross-device shares.
final clientSharedProjectsProvider = StreamProvider<List<ClientSharedProjectView>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return watchUnifiedClientProjects(ref, user);
});

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this.ref) : super(ThemeMode.light) {
    _load();
  }

  static const _prefsKey = 'clivora_theme_mode';

  final Ref ref;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      if (stored == 'dark') {
        if (!mounted) return;
        state = ThemeMode.dark;
        return;
      }
      if (stored == 'light') {
        if (!mounted) return;
        state = ThemeMode.light;
        return;
      }

      final userId = ref.read(authStateProvider).valueOrNull?.id;
      if (userId == null) return;
      final settings = await ref.read(databaseProvider).watchAppSettingsForUser(userId).first;
      if (!mounted) return;
      final mode = settings.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
      state = mode;
      await prefs.setString(_prefsKey, mode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {
      if (!mounted) return;
      state = ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode == ThemeMode.dark ? 'dark' : 'light');

    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return;
    await ref.read(databaseProvider).saveAppSettingsForUser(
          userId,
          AppSettingsTableCompanion(
            themeMode: Value(mode == ThemeMode.dark ? 'dark' : 'light'),
          ),
        );
  }
}

final customersProvider =
    StreamProvider.family<List<Customer>, String?>((ref, search) {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchCustomersForUser(ownerId, search: search);
});

final customerCountProvider = StreamProvider<int>((ref) {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return const Stream.empty();
  return ref
      .watch(databaseProvider)
      .watchCustomersForUser(ownerId)
      .map((list) => list.length);
});

final projectCountProvider = StreamProvider<int>((ref) {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return const Stream.empty();
  return ref
      .watch(databaseProvider)
      .watchProjectsForUser(ownerId)
      .map((list) => list.length);
});

final projectsProvider =
    StreamProvider.family<List<Project>, ProjectFilter>((ref, filter) {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchProjectsForUser(
        ownerId,
        search: filter.search,
        status: filter.status,
      );
});

class ProjectFilter {
  const ProjectFilter({this.search, this.status = 'all'});

  final String? search;
  final String status;

  @override
  bool operator ==(Object other) =>
      other is ProjectFilter &&
      other.search == search &&
      other.status == status;

  @override
  int get hashCode => Object.hash(search, status);
}

final projectStatsProvider = FutureProvider<ProjectStats>((ref) async {
  final ownerId = _ownerId(ref);
  if (ownerId == null) {
    return const ProjectStats(active: 0, earned: 0, unpaid: 0, totalTrackedSeconds: 0);
  }
  final db = ref.watch(databaseProvider);
  final active = await db.countActiveProjectsForUser(ownerId);
  final projects = await db.watchProjectsForUser(ownerId).first;
  double earned = 0;
  double unpaid = 0;
  var totalSeconds = 0;
  for (final p in projects) {
    if (p.status == 'completed') earned += p.budget;
    if (p.status == 'in_progress') unpaid += p.budget;
    totalSeconds += await db.totalSecondsForProjectForUser(ownerId, p.id);
  }
  return ProjectStats(
    active: active,
    earned: earned,
    unpaid: unpaid,
    totalTrackedSeconds: totalSeconds,
  );
});

class ProjectStats {
  const ProjectStats({
    required this.active,
    required this.earned,
    required this.unpaid,
    required this.totalTrackedSeconds,
  });

  final int active;
  final double earned;
  final double unpaid;
  final int totalTrackedSeconds;

  String get trackedHoursLabel => formatTrackedDuration(totalTrackedSeconds);
}

final invoicesProvider =
    StreamProvider.family<List<Invoice>, String?>((ref, status) {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchInvoicesForUser(ownerId, status: status);
});

final invoiceStatsProvider = FutureProvider<InvoiceStats>((ref) async {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return const InvoiceStats(total: 0, outstanding: 0, paid: 0);
  final db = ref.watch(databaseProvider);
  final all = await db.watchInvoicesForUser(ownerId).first;
  final outstanding = await db.sumOutstandingForUser(ownerId);
  final paid = await db.sumPaidForUser(ownerId);
  return InvoiceStats(
    total: all.length,
    outstanding: outstanding,
    paid: paid,
  );
});

class InvoiceStats {
  const InvoiceStats({
    required this.total,
    required this.outstanding,
    required this.paid,
  });

  final int total;
  final double outstanding;
  final double paid;
}

final monthlyInvoiceCountProvider = FutureProvider<int>((ref) async {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return 0;
  return ref.watch(databaseProvider).countInvoicesThisMonthForUser(ownerId);
});

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  ref.watch(authStateProvider);
  final ownerId = _ownerId(ref);
  if (ownerId == null) {
    return const DashboardStats(revenue: 0, totalInvoiced: 0, outstanding: 0, customers: 0, activeProjects: 0);
  }
  final db = ref.watch(databaseProvider);
  final customers = await db.countCustomersForUser(ownerId);
  final activeProjects = await db.countActiveProjectsForUser(ownerId);
  final outstanding = await db.sumOutstandingForUser(ownerId);
  final paid = await db.sumPaidForUser(ownerId);
  final totalInvoiced = await db.sumTotalInvoicedForUser(ownerId);
  return DashboardStats(
    revenue: paid,
    totalInvoiced: totalInvoiced,
    outstanding: outstanding,
    customers: customers,
    activeProjects: activeProjects,
  );
});

class DashboardStats {
  const DashboardStats({
    required this.revenue,
    required this.totalInvoiced,
    required this.outstanding,
    required this.customers,
    required this.activeProjects,
  });

  final double revenue;
  final double totalInvoiced;
  final double outstanding;
  final int customers;
  final int activeProjects;
}

final planLimitServiceProvider = Provider<PlanLimitService>((ref) {
  return PlanLimitService(ref);
});

class PlanLimitService {
  PlanLimitService(this.ref);

  final Ref ref;

  Future<String> currentPlan() async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return 'free';
    final settings = await ref.read(databaseProvider).watchAppSettingsForUser(userId).first;
    return settings.subscriptionPlan;
  }

  Future<bool> canAddCustomer() async {
    if (!await _emailOk()) return false;
    if (await _isPro()) return true;
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return false;
    final count = await ref.read(databaseProvider).countCustomersForUser(ownerId);
    return count < PlanLimits.freeMaxClients;
  }

  Future<bool> canAddProject() async {
    if (!await _emailOk()) return false;
    if (await _isPro()) return true;
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return false;
    final count = await ref.read(projectCountProvider.future);
    return count < PlanLimits.freeMaxProjects;
  }

  Future<bool> canAddInvoice() async {
    if (!await _emailOk()) return false;
    if (await _isPro()) return true;
    final count = await ref.read(monthlyInvoiceCountProvider.future);
    return count < PlanLimits.freeMaxInvoicesPerMonth;
  }

  Future<bool> canAddTemplate() async {
    if (!await _emailOk()) return false;
    if (await _isPro()) return true;
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return false;
    final count = await ref.read(databaseProvider).countMessageTemplatesForUser(ownerId);
    return count < PlanLimits.freeMaxTemplates;
  }

  Future<bool> canAddTaskToProject(int? projectId) async {
    if (!await _emailOk()) return false;
    if (await _isPro()) return true;
    if (projectId == null) return true;
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return false;
    final count = await ref.read(databaseProvider).countTasksForProjectForUser(ownerId, projectId);
    return count < PlanLimits.freeMaxTasksPerProject;
  }

  Future<bool> canAddClientContract(int currentCount) async {
    if (!await _emailOk()) return false;
    if (await _isPro()) return true;
    return currentCount < PlanLimits.freeMaxClientContracts;
  }

  /// Soft gate for create actions that do not have a free-tier count limit.
  Future<bool> canCreateWork() async => _emailOk();

  Future<bool> canDownloadClientInvoicePdf() async {
    if (await _isPro()) return true;
    return ref.read(clientPdfQuotaServiceProvider).canDownload();
  }

  Future<bool> canUseBiometric() async {
    return PlanFeatures.biometricLock(await currentPlan());
  }

  Future<bool> canUseAi() async => PlanFeatures.aiAssistant(await currentPlan());

  Future<bool> canUseWorkflows() async => PlanFeatures.customWorkflows(await currentPlan());

  Future<bool> canUseAdvancedAnalytics() async => PlanFeatures.advancedAnalytics(await currentPlan());

  Future<int> storageLimitBytes() async =>
      PlanFeatures.fileVaultLimitBytes(await currentPlan());

  Future<bool> _isPro() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (isAdminUser(user)) return true;
    return PlanFeatures.isPro(await currentPlan());
  }

  Future<bool> _emailOk() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return false;
    if (isAdminUser(user)) return true;
    if (user.email.toLowerCase().endsWith('@clivora.local')) return true;
    if (user.emailVerified) return true;
    final cloud = SupabaseAuthHelper.client.auth.currentUser;
    if (cloud?.emailConfirmedAt != null) return true;
    if ((cloud?.identities ?? const []).any((i) => i.provider == 'google')) return true;
    return false;
  }

  Future<void> setPlan(String plan) async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return;
    await setPlanForUser(userId, plan);
  }

  Future<void> setPlanForUser(int userId, String plan) async {
    await ref.read(databaseProvider).saveAppSettingsForUser(
          userId,
          AppSettingsTableCompanion(subscriptionPlan: Value(plan)),
        );
    final currentId = ref.read(authStateProvider).valueOrNull?.id;
    if (currentId == userId) {
      ref.invalidate(appSettingsProvider);
    }
  }
}

/// Community edition: every feature is available, so Pro checks always pass.
final isProProvider = Provider<bool>((ref) => true);

/// True when cloud/local plan is Pro Plus (admins always have Plus).
final isProPlusProvider = Provider<bool>((ref) => true);

/// Supabase profiles.subscription_plan (admin grants, server truth when online).
final cloudSubscriptionPlanProvider = FutureProvider<String?>((ref) async {
  ref.watch(authStateProvider);
  final profile = await SupabaseAuthHelper.fetchOwnProfile();
  return profile?['subscription_plan'] as String?;
});

/// Server-verified subscription from Supabase (when online).
/// `true` = active row, `false` = only expired/inactive rows, `null` = no rows / offline.
final serverSubscriptionProvider = FutureProvider<bool?>((ref) async {
  final uid = SupabaseAuthHelper.currentUid;
  if (uid == null) return null;
  try {
    final rows = await SupabaseAuthHelper.client
        .from('subscriptions')
        .select('status, expires_at, product_id')
        .eq('user_id', uid)
        .order('expires_at', ascending: false)
        .limit(8);
    final list = (rows as List?) ?? const [];
    if (list.isEmpty) return null;
    for (final row in list) {
      final map = Map<String, dynamic>.from(row as Map);
      final status = (map['status'] as String?)?.toLowerCase();
      final expires = map['expires_at'] as String?;
      final exp = expires == null ? null : DateTime.tryParse(expires);
      final notExpired = exp == null || exp.isAfter(DateTime.now());
      if (status == 'active' && notExpired) return true;
    }
    return false;
  } catch (_) {
    return null;
  }
});

final subscriptionPlanProvider = StreamProvider<String>((ref) {
  final userId = _ownerId(ref);
  if (userId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchAppSettingsForUser(userId).map((s) => s.subscriptionPlan);
});

final teamMembersProvider = StreamProvider<List<TeamMember>>((ref) {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchTeamMembers(ownerId);
});

final clientInboxProvider = StreamProvider<List<ClientMessage>>((ref) {
  final userId = _ownerId(ref);
  if (userId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchInboxForUser(userId);
});

/// Client inbox, local + Supabase (cross-device).
final unifiedClientInboxProvider = StreamProvider<List<ClientInboxEntry>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return watchUnifiedClientInbox(ref, user);
});

/// Freelancer mailbox, sent + received (Supabase).
final freelancerMailboxProvider = StreamProvider<List<CloudMessage>>((ref) {
  ref.watch(authStateProvider);
  final uid = SupabaseAuthHelper.currentUid;
  if (uid == null || uid.isEmpty) return Stream.value(const <CloudMessage>[]);
  return ref.watch(cloudMessageRepositoryProvider).watchFreelancerMailbox(uid: uid);
});

final unreadMessagesProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return 0;
  var count = 0;
  if (isClientUser(user)) {
    ref.watch(unifiedClientInboxProvider);
    final inbox = await ref.read(unifiedClientInboxProvider.future);
    count += inbox.where((m) => !m.isRead).length;
  } else {
    count += await ref.read(freelancerUnreadProvider.future);
  }
  count += await ref.read(cloudUnreadCountProvider.future);
  return count;
});

final freelancerUnreadProvider = FutureProvider<int>((ref) async {
  ref.watch(freelancerMailboxProvider);
  final uid = SupabaseAuthHelper.currentUid;
  if (uid == null) return 0;
  final mailbox = await ref.read(freelancerMailboxProvider.future);
  return mailbox.where((m) => m.toUid == uid && !m.isRead).length;
});

final clientCloudInvoicesProvider = StreamProvider<List<CloudInvoiceShare>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return ref.watch(cloudInvoiceRepositoryProvider).watchForClient(
        email: user.email,
        uid: SupabaseAuthHelper.currentUid,
      );
});

final clientInvoicesProvider = StreamProvider<List<Invoice>>((ref) {
  final userId = ref.watch(authStateProvider).valueOrNull?.id;
  if (userId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchInvoicesForClientStream(userId);
});

final clientContractsProvider = StreamProvider<List<ClientContractView>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return _watchClientContracts(ref, user);
});

Stream<List<ClientContractView>> _watchClientContracts(Ref ref, User user) {
  final db = ref.read(databaseProvider);
  final controller = StreamController<List<ClientContractView>>();
  var inbox = <ClientInboxEntry>[];
  var local = <Contract>[];

  void emit() => controller.add(mergeClientContractViews(inbox: inbox, local: local));

  final inboxSub = watchUnifiedClientInbox(ref, user).listen(
    (value) {
      inbox = value;
      emit();
    },
    onError: controller.addError,
  );
  final localSub = db.watchContractsForClient(user.id).listen(
    (value) {
      local = value;
      emit();
    },
    onError: controller.addError,
  );

  ref.onDispose(() {
    inboxSub.cancel();
    localSub.cancel();
    controller.close();
  });

  return controller.stream;
}

class ClientActivityItem {
  const ClientActivityItem({
    required this.projectId,
    required this.projectName,
    required this.status,
    required this.note,
    required this.createdAt,
  });

  final int projectId;
  final String projectName;
  final String status;
  final String note;
  final DateTime createdAt;
}

final clientActivityProvider = StreamProvider<List<ClientActivityItem>>((ref) async* {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    yield [];
    return;
  }
  final db = ref.watch(databaseProvider);
  await for (final projects in db.watchProjectsForClient(user.id)) {
    final items = <ClientActivityItem>[];
    for (final project in projects) {
      final events = await db.watchTrackingForClientProject(
        clientUserId: user.id,
        projectId: project.id,
      ).first;
      for (final e in events) {
        items.add(ClientActivityItem(
          projectId: project.id,
          projectName: project.name,
          status: e.status,
          note: e.note,
          createdAt: e.createdAt,
        ));
      }
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    yield items.take(50).toList();
  }
});

/// Combined unread badge for dashboard / client portal bells (live streams).
final unreadBadgeCountProvider = Provider<int>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return 0;
  final uid = SupabaseAuthHelper.currentUid;
  var count = 0;

  final cloud = ref.watch(cloudNotificationsProvider).valueOrNull ?? [];
  count += cloud.where((n) => !n.isRead).length;

  if (isClientUser(user)) {
    final inbox = ref.watch(unifiedClientInboxProvider).valueOrNull ?? [];
    count += inbox.where((m) => !m.isRead).length;
  } else if (uid != null) {
    final mailbox = ref.watch(freelancerMailboxProvider).valueOrNull ?? [];
    count += mailbox.where((m) => m.toUid == uid && !m.isRead).length;
    final tasks = ref.watch(freelancerClientTasksProvider).valueOrNull ?? [];
    count += tasks.where((t) => !t.isRead).length;
  }

  return count;
});

final notificationBadgeProvider = Provider<bool>((ref) => ref.watch(unreadBadgeCountProvider) > 0);

final messageTemplatesProvider =
    StreamProvider.family<List<MessageTemplate>, String?>((ref, category) {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchMessageTemplatesForUser(ownerId, category: category);
});

final contractsProvider =
    StreamProvider.family<List<Contract>, String?>((ref, status) {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchContractsForUser(ownerId, status: status);
});

// Tasks
final tasksProvider =
    StreamProvider.family<List<Task>, TaskFilter>((ref, filter) {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchTasksForUser(
        ownerId,
        status: filter.status,
        upcoming: filter.upcoming,
      );
});

class TaskFilter {
  const TaskFilter({this.status = 'all', this.upcoming = false});

  final String status;
  final bool upcoming;

  @override
  bool operator ==(Object other) =>
      other is TaskFilter && other.status == status && other.upcoming == upcoming;

  @override
  int get hashCode => Object.hash(status, upcoming);
}

// Expenses
final expensesProvider =
    StreamProvider.family<List<Expense>, String?>((ref, category) {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchExpensesForUser(ownerId, category: category);
});

final expenseStatsProvider = FutureProvider<ExpenseStats>((ref) async {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return const ExpenseStats(total: 0, monthly: 0, count: 0);
  final db = ref.watch(databaseProvider);
  final all = await db.watchExpensesForUser(ownerId).first;
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month);
  double monthly = 0;
  double total = 0;
  for (final e in all) {
    total += e.amount;
    if (e.expenseDate.isAfter(monthStart.subtract(const Duration(days: 1)))) {
      monthly += e.amount;
    }
  }
  return ExpenseStats(total: total, monthly: monthly, count: all.length);
});

class ExpenseStats {
  const ExpenseStats({
    required this.total,
    required this.monthly,
    required this.count,
  });

  final double total;
  final double monthly;
  final int count;
}

// Notes
final notesProvider = StreamProvider.family<List<Note>, String?>((ref, type) {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchNotesForUser(ownerId, type: type);
});

// Reports
final reportsProvider = FutureProvider<ReportData>((ref) async {
  final ownerId = _ownerId(ref);
  if (ownerId == null) {
    return const ReportData(
      revenue: 0, outstanding: 0, monthlyExpenses: 0, totalExpenses: 0,
      profit: 0, monthlyProfit: 0, customers: 0, projects: 0, pendingTasks: 0,
      agingCurrent: 0, aging30: 0, aging60: 0, aging90: 0, taxCollected: 0,
    );
  }
  final db = ref.watch(databaseProvider);
  final paid = await db.sumPaidForUser(ownerId);
  final outstanding = await db.sumOutstandingForUser(ownerId);
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month);
  final expenses = await db.sumExpensesForUser(ownerId, since: monthStart);
  final totalExpenses = await db.sumExpensesForUser(ownerId);
  final customers = await db.countCustomersForUser(ownerId);
  final projects = await db.countProjectsForUser(ownerId);
  final pendingTasks = await db.countPendingTasksForUser(ownerId);

  final invoices = await db.watchInvoicesForUser(ownerId).first;
  var agingCurrent = 0.0, aging30 = 0.0, aging60 = 0.0, aging90 = 0.0, taxCollected = 0.0;
  for (final inv in invoices) {
    if (inv.status == 'paid') {
      taxCollected += inv.subtotal * (inv.taxRate / 100);
      continue;
    }
    if (inv.status != 'sent' && inv.status != 'overdue') continue;
    final balance = (inv.total - inv.amountPaid).clamp(0, double.infinity);
    final due = inv.dueDate ?? inv.issueDate;
    final days = now.difference(due).inDays;
    if (days <= 0) {
      agingCurrent += balance;
    } else if (days <= 30) {
      aging30 += balance;
    } else if (days <= 60) {
      aging60 += balance;
    } else {
      aging90 += balance;
    }
  }

  return ReportData(
    revenue: paid,
    outstanding: outstanding,
    monthlyExpenses: expenses,
    totalExpenses: totalExpenses,
    profit: paid - totalExpenses,
    monthlyProfit: paid - expenses,
    customers: customers,
    projects: projects,
    pendingTasks: pendingTasks,
    agingCurrent: agingCurrent,
    aging30: aging30,
    aging60: aging60,
    aging90: aging90,
    taxCollected: taxCollected,
  );
});

class ReportData {
  const ReportData({
    required this.revenue,
    required this.outstanding,
    required this.monthlyExpenses,
    required this.totalExpenses,
    required this.profit,
    required this.monthlyProfit,
    required this.customers,
    required this.projects,
    required this.pendingTasks,
    this.agingCurrent = 0,
    this.aging30 = 0,
    this.aging60 = 0,
    this.aging90 = 0,
    this.taxCollected = 0,
  });

  final double revenue;
  final double outstanding;
  final double monthlyExpenses;
  final double totalExpenses;
  final double profit;
  final double monthlyProfit;
  final int customers;
  final int projects;
  final int pendingTasks;
  final double agingCurrent;
  final double aging30;
  final double aging60;
  final double aging90;
  final double taxCollected;
}

// Notifications
final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final db = ref.watch(databaseProvider);
  final notifications = <AppNotification>[];
  final now = DateTime.now();

  final unread = await db.countUnreadMessages(user.id);
  if (unread > 0) {
    notifications.add(AppNotification(
      title: unread == 1 ? '1 new message' : '$unread new messages',
      message: isClientUser(user)
          ? 'Open Messages to read updates from your freelancer'
          : 'You have unread client messages',
      type: NotificationType.message,
      route: isClientUser(user) ? '/client-messages' : '/freelancer-messages',
      priority: 0,
    ));
  }

  if (isClientUser(user)) {
    notifications.sort((a, b) => a.priority.compareTo(b.priority));
    return notifications;
  }

  final ownerId = user.id;
  final allInvoices = await db.watchInvoicesForUser(ownerId).first;
  for (final inv in allInvoices.where((i) => i.status == 'overdue')) {
    notifications.add(AppNotification(
      title: 'Overdue Invoice ${inv.invoiceNumber}',
      message: 'Payment is overdue',
      type: NotificationType.invoice,
      route: '/invoices/${inv.id}/edit',
      priority: 0,
    ));
  }
  for (final inv in allInvoices.where((i) => i.status == 'sent')) {
    notifications.add(AppNotification(
      title: 'Pending Payment ${inv.invoiceNumber}',
      message: 'Invoice sent, awaiting payment',
      type: NotificationType.invoice,
      route: '/invoices/${inv.id}/edit',
      priority: 2,
    ));
  }

  final tasks = await db.watchTasksForUser(ownerId).first;
  for (final task in tasks.where((t) => !t.completed && t.dueDate != null)) {
    if (task.dueDate!.isBefore(now.add(const Duration(days: 1)))) {
      notifications.add(AppNotification(
        title: 'Task Due: ${task.title}',
        message: 'Due ${task.dueDate!.toLocal().toString().split(' ').first}',
        type: NotificationType.task,
        route: '/tasks/${task.id}/edit',
        priority: task.dueDate!.isBefore(now) ? 1 : 3,
      ));
    }
  }

  notifications.sort((a, b) => a.priority.compareTo(b.priority));
  return notifications;
});

enum NotificationType { invoice, task, project, message }

class AppNotification {
  const AppNotification({
    required this.title,
    required this.message,
    required this.type,
    required this.route,
    required this.priority,
  });

  final String title;
  final String message;
  final NotificationType type;
  final String route;
  final int priority;
}

// Calendar events
final calendarEventsProvider = FutureProvider<List<CalendarEvent>>((ref) async {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return [];
  final db = ref.watch(databaseProvider);
  final events = <CalendarEvent>[];

  final tasks = await db.watchTasksForUser(ownerId).first;
  for (final task in tasks.where((t) => t.dueDate != null)) {
    events.add(CalendarEvent(
      title: task.title,
      date: task.dueDate!,
      type: 'task',
      color: task.completed ? Colors.grey : Colors.blue,
    ));
  }

  final projects = await db.watchProjectsForUser(ownerId).first;
  for (final project in projects.where((p) => p.deadline != null)) {
    events.add(CalendarEvent(
      title: '${project.name} deadline',
      date: project.deadline!,
      type: 'project',
      color: Colors.orange,
    ));
  }

  final invoices = await db.watchInvoicesForUser(ownerId).first;
  for (final inv in invoices.where((i) => i.dueDate != null)) {
    events.add(CalendarEvent(
      title: 'Invoice ${inv.invoiceNumber} due',
      date: inv.dueDate!,
      type: 'invoice',
      color: inv.status == 'overdue' ? Colors.red : Colors.green,
    ));
  }

  final tracking = await db.watchAllTrackingForUser(ownerId);
  for (final t in tracking.take(200)) {
    events.add(CalendarEvent(
      title: t.note.isNotEmpty ? t.note : '${t.entityType} update',
      date: t.createdAt,
      type: 'activity',
      color: Colors.teal,
    ));
  }

  events.sort((a, b) => a.date.compareTo(b.date));
  return events;
});

final calendarRemindersProvider = StreamProvider<List<CalendarEvent>>((ref) async* {
  final ownerId = _ownerId(ref);
  if (ownerId == null) {
    yield [];
    return;
  }
  await for (final reminders in ref.watch(databaseProvider).watchRemindersForUser(ownerId)) {
    yield reminders
        .map(
          (r) => CalendarEvent(
            title: r.title,
            date: r.scheduledAt,
            type: r.kind,
            color: Colors.purple,
          ),
        )
        .toList();
  }
});

class CalendarEvent {
  const CalendarEvent({
    required this.title,
    required this.date,
    required this.type,
    required this.color,
  });

  final String title;
  final DateTime date;
  final String type;
  final Color color;
}

final productsProvider = StreamProvider<List<Product>>((ref) {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchProductsForUser(ownerId);
});

final quotesProvider = StreamProvider.family<List<Quote>, String?>((ref, status) {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchQuotesForUser(ownerId, status: status);
});

final recurringInvoicesProvider = StreamProvider<List<RecurringInvoice>>((ref) {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchRecurringInvoicesForUser(ownerId);
});

final vendorsProvider = StreamProvider<List<Vendor>>((ref) {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchVendorsForUser(ownerId);
});

final purchaseOrdersProvider = StreamProvider<List<PurchaseOrder>>((ref) {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchPurchaseOrdersForUser(ownerId);
});

final creditsProvider = StreamProvider<List<Credit>>((ref) {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchCreditsForUser(ownerId);
});

final invoicePaymentsProvider = StreamProvider<List<InvoicePayment>>((ref) {
  final ownerId = _ownerId(ref);
  if (ownerId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchPaymentsForUser(ownerId);
});

/// 30-day revenue series for dashboard sparkline (paid invoice totals by day).
final revenueSparklineProvider = FutureProvider<List<double>>((ref) async {
  // Recompute whenever auth owner changes (sign-out / sign-in).
  ref.watch(authStateProvider);
  final ownerId = _ownerId(ref);
  if (ownerId == null) return List.filled(30, 0);
  final invoices = await ref.read(databaseProvider).watchInvoicesForUser(ownerId).first;
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
  final series = List<double>.filled(30, 0);
  for (final inv in invoices) {
    if (inv.status != 'paid') continue;
    final day = DateTime(inv.updatedAt.year, inv.updatedAt.month, inv.updatedAt.day);
    final idx = day.difference(start).inDays;
    if (idx >= 0 && idx < 30) series[idx] += inv.total;
  }
  return series;
});
