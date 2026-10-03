import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/cloud/cloud_message_repository.dart';
import '../../core/cloud/cloud_notification_repository.dart';
import '../../core/cloud/supabase_auth_helper.dart';
import '../../core/services/audit_log_service.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/services/recurring_invoice_service.dart';
import '../../core/services/tracking_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/utils/template_utils.dart';
import '../../data/models/invoice_line_item.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/database/database.dart';
import '../../data/providers/app_providers.dart';

final automationSettingsProvider =
    StateNotifierProvider<AutomationSettingsNotifier, AutomationSettings>((ref) {
  return AutomationSettingsNotifier();
});

class AutomationSettings {
  const AutomationSettings({
    this.overdueFollowUp = true,
    this.customerWelcome = true,
    this.weeklySummary = false,
    this.taskAssignedMessage = true,
    this.contractSignedStage = true,
    this.inactiveClientReminder = true,
  });

  final bool overdueFollowUp;
  final bool customerWelcome;
  final bool weeklySummary;
  final bool taskAssignedMessage;
  final bool contractSignedStage;
  final bool inactiveClientReminder;

  AutomationSettings copyWith({
    bool? overdueFollowUp,
    bool? customerWelcome,
    bool? weeklySummary,
    bool? taskAssignedMessage,
    bool? contractSignedStage,
    bool? inactiveClientReminder,
  }) {
    return AutomationSettings(
      overdueFollowUp: overdueFollowUp ?? this.overdueFollowUp,
      customerWelcome: customerWelcome ?? this.customerWelcome,
      weeklySummary: weeklySummary ?? this.weeklySummary,
      taskAssignedMessage: taskAssignedMessage ?? this.taskAssignedMessage,
      contractSignedStage: contractSignedStage ?? this.contractSignedStage,
      inactiveClientReminder: inactiveClientReminder ?? this.inactiveClientReminder,
    );
  }
}

class AutomationSettingsNotifier extends StateNotifier<AutomationSettings> {
  AutomationSettingsNotifier() : super(const AutomationSettings()) {
    _load();
  }

  static const _kOverdue = 'auto_overdue_followup';
  static const _kWelcome = 'auto_customer_welcome';
  static const _kWeekly = 'auto_weekly_summary';
  static const _kWeeklyLast = 'auto_weekly_summary_last';
  static const _kTaskMsg = 'auto_task_assigned_message';
  static const _kContractStage = 'auto_contract_signed_stage';
  static const _kInactive = 'auto_inactive_client_reminder';
  static const _kInactiveLast = 'auto_inactive_client_last';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AutomationSettings(
      overdueFollowUp: prefs.getBool(_kOverdue) ?? true,
      customerWelcome: prefs.getBool(_kWelcome) ?? true,
      weeklySummary: prefs.getBool(_kWeekly) ?? false,
      taskAssignedMessage: prefs.getBool(_kTaskMsg) ?? true,
      contractSignedStage: prefs.getBool(_kContractStage) ?? true,
      inactiveClientReminder: prefs.getBool(_kInactive) ?? true,
    );
  }

  Future<void> setOverdueFollowUp(bool value) async {
    state = state.copyWith(overdueFollowUp: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOverdue, value);
  }

  Future<void> setCustomerWelcome(bool value) async {
    state = state.copyWith(customerWelcome: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWelcome, value);
  }

  Future<void> setWeeklySummary(bool value) async {
    state = state.copyWith(weeklySummary: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWeekly, value);
  }

  Future<void> setTaskAssignedMessage(bool value) async {
    state = state.copyWith(taskAssignedMessage: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTaskMsg, value);
  }

  Future<void> setContractSignedStage(bool value) async {
    state = state.copyWith(contractSignedStage: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kContractStage, value);
  }

  Future<void> setInactiveClientReminder(bool value) async {
    state = state.copyWith(inactiveClientReminder: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kInactive, value);
  }
}

final automationServiceProvider = Provider<AutomationService>((ref) {
  return AutomationService(ref);
});

class AutomationService {
  AutomationService(this.ref);

  final Ref ref;

  Future<void> logRun(String key, String detail) async {
    try {
      final uid = SupabaseAuthHelper.currentUid;
      await SupabaseAuthHelper.client.from('automation_run_log').insert({
        'user_uid': ?uid,
        'automation_key': key,
        'detail': detail,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('automation_run_log write failed: $e');
    }
  }

  Future<List<Map<String, dynamic>>> recentRuns({int limit = 20}) async {
    try {
      final uid = SupabaseAuthHelper.currentUid;
      final rows = uid != null
          ? await SupabaseAuthHelper.client
              .from('automation_run_log')
              .select()
              .eq('user_uid', uid)
              .order('created_at', ascending: false)
              .limit(limit)
          : await SupabaseAuthHelper.client
              .from('automation_run_log')
              .select()
              .order('created_at', ascending: false)
              .limit(limit);
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('automation_run_log read failed: $e');
      return [];
    }
  }

  Future<void> onCustomerCreated(Customer customer) async {
    if (!ref.read(automationSettingsProvider).customerWelcome) return;
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return;
    final db = ref.read(databaseProvider);
    final emails = parseStringList(customer.emails);
    if (emails.isEmpty) return;

    await db.insertNote(
      NotesCompanion.insert(
        ownerUserId: ownerId,
        title: 'Welcome ${customer.contactPerson}',
        content: Value('Invite sent to ${emails.first}. Confirm project scope and next steps.'),
        type: Value('client'),
        customerId: Value(customer.id),
      ),
    );
    await db.insertTask(
      TasksCompanion.insert(
        ownerUserId: ownerId,
        title: 'Welcome ${customer.contactPerson}',
        description: Value('Confirm client received invite and project details.'),
        customerId: Value(customer.id),
        priority: Value('medium'),
      ),
    );
    await logRun('customer_welcome', 'Welcome flow for ${customer.contactPerson}');
    // Welcome / invite message is sent via ClientInviteService when the customer is created.
  }

  Future<void> onClientAccountLinked(int clientUserId, int freelancerUserId) async {
    if (!ref.read(automationSettingsProvider).customerWelcome) return;
    final db = ref.read(databaseProvider);
    final freelancer = await db.getUser(freelancerUserId);
    final client = await db.getUser(clientUserId);
    if (freelancer == null || client == null) return;
    final profile = await db.watchBusinessProfileForUser(freelancerUserId).first;
    final businessName = profile.businessName.isNotEmpty ? profile.businessName : profile.ownerName;
    await ref.read(cloudMessageRepositoryProvider).sendHybrid(
      fromUser: freelancer,
      toEmail: client.email,
      subject: 'Welcome to $businessName',
      body:
          'Hi! Your freelancer has connected you on Clivora. You can now view shared projects, hours tracked, invoices, and messages here.',
      localToUserId: clientUserId,
    );
  }

  Future<void> onInvoiceSaved(Invoice invoice, {String? previousStatus}) async {
    if (!ref.read(automationSettingsProvider).overdueFollowUp) return;
    if (invoice.status != 'overdue') return;
    if (previousStatus == 'overdue') return;

    final db = ref.read(databaseProvider);
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return;
    final existing = await db.watchTasksForUser(ownerId).first;
    final already = existing.any(
      (t) => t.title.contains(invoice.invoiceNumber) && !t.completed,
    );
    if (already) return;

    await db.insertTask(
      TasksCompanion.insert(
        ownerUserId: ownerId,
        title: 'Follow up: ${invoice.invoiceNumber}',
        description: Value('Invoice is overdue. Send payment reminder to client.'),
        customerId: Value(invoice.customerId),
        projectId: Value(invoice.projectId),
        priority: Value('high'),
        dueDate: Value(DateTime.now()),
      ),
    );

    final template = await resolveMessageTemplate(
      db,
      ownerId,
      category: 'invoice',
      nameHint: 'payment',
      fallbackSubject: 'Invoice {{invoiceNumber}}: payment reminder',
      fallbackBody:
          'Hi {{clientName}},\n\nThis is a friendly reminder that invoice {{invoiceNumber}} for {{amount}} is now overdue. Please let us know if you need a copy resent or wish to discuss payment options.\n\nBest regards,\n{{businessName}}',
    );
    final subject = await fillTemplateForInvoice(db, ownerId, template.subject, invoice);
    final body = await fillTemplateForInvoice(db, ownerId, template.body, invoice);

    if (invoice.projectId != null) {
      final link = await (db.select(db.projectClientLinks)
            ..where((t) => t.projectId.equals(invoice.projectId!)))
          .getSingleOrNull();
      final fromUser = ref.read(authStateProvider).valueOrNull;
      if (fromUser != null && link != null) {
        final clientUser = link.clientUserId != null ? await db.getUser(link.clientUserId!) : null;
        final clientEmail = clientUser?.email ?? link.clientEmail;
        await ref.read(cloudMessageRepositoryProvider).sendHybrid(
          fromUser: fromUser,
          toEmail: clientEmail,
          subject: subject,
          body: body,
          localToUserId: link.clientUserId,
          localProjectId: invoice.projectId,
        );
        await ref.read(cloudNotificationRepositoryProvider).send(
              toEmail: clientEmail,
              title: 'Payment reminder: ${invoice.invoiceNumber}',
              body: subject,
              kind: 'invoice',
            );
      }
    }
  }

  /// Generates due recurring invoices and surfaces upcoming reminders.
  Future<void> processRecurringInvoices() async {
    try {
      await ref.read(recurringInvoiceServiceProvider).processDue();
    } catch (_) {}
  }

  Future<void> runWeeklySummaryIfDue() async {
    await processRecurringInvoices();
    if (!ref.read(automationSettingsProvider).weeklySummary) return;
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(AutomationSettingsNotifier._kWeeklyLast) ?? 0;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    final now = DateTime.now();
    if (now.difference(last).inDays < 7) return;

    final db = ref.read(databaseProvider);
    final invoices = await db.watchInvoicesForUser(ownerId).first;
    final paid = invoices.where((i) => i.status == 'paid').fold<double>(0, (s, i) => s + i.total);
    final outstanding = invoices.where((i) => i.status == 'sent' || i.status == 'overdue').fold<double>(0, (s, i) => s + i.total);

    await db.insertNote(
      NotesCompanion.insert(
        ownerUserId: ownerId,
        title: 'Weekly revenue summary',
        content: Value(
          'Collected: USD ${paid.toStringAsFixed(0)} · Outstanding: USD ${outstanding.toStringAsFixed(0)} · ${invoices.length} total invoices.',
        ),
        type: Value('report'),
      ),
    );
    await prefs.setInt(AutomationSettingsNotifier._kWeeklyLast, now.millisecondsSinceEpoch);
  }

  Future<void> onTaskAssigned(Task task, {String? clientEmail, int? clientUserId}) async {
    if (!ref.read(automationSettingsProvider).taskAssignedMessage) return;
    if (clientEmail == null || clientEmail.isEmpty) return;
    final fromUser = ref.read(authStateProvider).valueOrNull;
    if (fromUser == null) return;

    await ref.read(cloudMessageRepositoryProvider).sendHybrid(
          fromUser: fromUser,
          toEmail: clientEmail,
          subject: 'New task: ${task.title}',
          body: task.description.isNotEmpty ? task.description : 'You have a new task assigned.',
          localToUserId: clientUserId,
          localProjectId: task.projectId,
        );
    await ref.read(cloudNotificationRepositoryProvider).send(
          toEmail: clientEmail,
          title: 'Task assigned: ${task.title}',
          body: task.description.isNotEmpty ? task.description : 'Open Tasks to view details.',
          kind: 'task',
        );
    await ref.read(pushNotificationServiceProvider).notify(
          title: 'Task assigned',
          body: task.title,
          kind: 'task',
        );
  }

  Future<void> onContractSigned(Contract contract) async {
    await ref.read(auditLogServiceProvider).logContractSigned(
          contractId: contract.id,
          title: contract.title,
        );
    if (!ref.read(automationSettingsProvider).contractSignedStage) return;

    final db = ref.read(databaseProvider);
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return;

    final projects = await db.watchProjectsForUser(ownerId).first;
    final linked = projects.where((p) => p.customerId == contract.customerId && p.status != 'completed').toList();
    for (final project in linked.take(1)) {
      await db.updateProject(project.copyWith(status: 'in_progress', updatedAt: DateTime.now()));
      await ref.read(trackingServiceProvider).logStatusChange(
            entityType: 'project',
            entityId: project.id,
            status: 'in_progress',
            note: 'Contract "${contract.title}" signed',
          );
    }
  }

  Future<void> runInactiveClientCheckIfDue() async {
    if (!ref.read(automationSettingsProvider).inactiveClientReminder) return;
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(AutomationSettingsNotifier._kInactiveLast) ?? 0;
    if (DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastMs)).inDays < 1) return;

    final db = ref.read(databaseProvider);
    final customers = await db.watchCustomersForUser(ownerId).first;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));

    for (final customer in customers) {
      if (customer.updatedAt.isAfter(cutoff)) continue;
      final existing = await db.watchTasksForUser(ownerId).first;
      final already = existing.any((t) => t.title.contains(customer.contactPerson) && t.title.contains('inactive'));
      if (already) continue;

      await db.insertTask(
        TasksCompanion.insert(
          ownerUserId: ownerId,
          title: 'Follow up: ${customer.contactPerson} inactive',
          description: Value('No activity in 7+ days. Send a check-in message.'),
          customerId: Value(customer.id),
          priority: Value('medium'),
          dueDate: Value(DateTime.now()),
        ),
      );
    }
    await prefs.setInt(AutomationSettingsNotifier._kInactiveLast, DateTime.now().millisecondsSinceEpoch);
  }
}
