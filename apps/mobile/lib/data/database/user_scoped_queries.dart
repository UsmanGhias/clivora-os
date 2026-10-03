import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'database.dart';
import 'user_defaults.dart';

/// All CRM queries scoped by [ownerUserId], prevents cross-user data leaks on shared devices.
extension UserScopedQueries on AppDatabase {
  //, , Customers, , 
  Stream<List<Customer>> watchCustomersForUser(int ownerUserId, {String? search}) {
    final query = select(customers)
      ..where((t) => t.ownerUserId.equals(ownerUserId))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (search != null && search.isNotEmpty) {
      final term = '%$search%';
      query.where(
        (t) =>
            t.ownerUserId.equals(ownerUserId) &
            (t.contactPerson.like(term) | t.company.like(term) | t.emails.like(term)),
      );
    }
    return query.watch();
  }

  Future<int> countCustomersForUser(int ownerUserId) async {
    return (select(customers)..where((t) => t.ownerUserId.equals(ownerUserId))).get().then((l) => l.length);
  }

  Future<Customer?> getCustomerForUser(int ownerUserId, int id) =>
      (select(customers)..where((t) => t.id.equals(id) & t.ownerUserId.equals(ownerUserId))).getSingleOrNull();

  //, , Projects, , 
  Stream<List<Project>> watchProjectsForUser(int ownerUserId, {String? search, String? status}) {
    final query = select(projects)
      ..where((t) => t.ownerUserId.equals(ownerUserId))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (search != null && search.isNotEmpty) {
      final term = '%$search%';
      query.where(
        (t) =>
            t.ownerUserId.equals(ownerUserId) &
            (t.name.like(term) | t.description.like(term)),
      );
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      query.where((t) => t.ownerUserId.equals(ownerUserId) & t.status.equals(status));
    }
    return query.watch();
  }

  Future<Project?> getProjectForUser(int ownerUserId, int id) =>
      (select(projects)..where((t) => t.id.equals(id) & t.ownerUserId.equals(ownerUserId))).getSingleOrNull();

  Future<int> countProjectsForUser(int ownerUserId) async {
    return (select(projects)..where((t) => t.ownerUserId.equals(ownerUserId))).get().then((l) => l.length);
  }

  Future<int> countActiveProjectsForUser(int ownerUserId) async {
    return (select(projects)
          ..where((t) => t.ownerUserId.equals(ownerUserId) & t.status.equals('in_progress')))
        .get()
        .then((l) => l.length);
  }

  //, , Invoices, , 
  Stream<List<Invoice>> watchInvoicesForUser(int ownerUserId, {String? status}) {
    final query = select(invoices)
      ..where((t) => t.ownerUserId.equals(ownerUserId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (status != null && status.isNotEmpty && status != 'all') {
      if (status == 'outstanding') {
        query.where(
          (t) =>
              t.ownerUserId.equals(ownerUserId) &
              (t.status.equals('sent') | t.status.equals('overdue')),
        );
      } else {
        query.where((t) => t.ownerUserId.equals(ownerUserId) & t.status.equals(status));
      }
    }
    return query.watch();
  }

  Future<Invoice?> getInvoiceForUser(int ownerUserId, int id) =>
      (select(invoices)..where((t) => t.id.equals(id) & t.ownerUserId.equals(ownerUserId))).getSingleOrNull();

  Future<double> sumOutstandingForUser(int ownerUserId) async {
    final rows = await (select(invoices)
          ..where(
            (t) =>
                t.ownerUserId.equals(ownerUserId) &
                (t.status.equals('sent') | t.status.equals('overdue')),
          ))
        .get();
    return rows.fold<double>(0, (sum, i) => sum + i.total);
  }

  Future<double> sumPaidForUser(int ownerUserId) async {
    final rows = await (select(invoices)
          ..where((t) => t.ownerUserId.equals(ownerUserId) & t.status.equals('paid')))
        .get();
    return rows.fold<double>(0, (sum, i) => sum + i.total);
  }

  Future<double> sumTotalInvoicedForUser(int ownerUserId) async {
    final rows = await (select(invoices)..where((t) => t.ownerUserId.equals(ownerUserId))).get();
    return rows.fold<double>(0, (sum, i) => sum + i.total);
  }

  Future<int> countInvoicesThisMonthForUser(int ownerUserId) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);
    return (select(invoices)
          ..where(
            (t) =>
                t.ownerUserId.equals(ownerUserId) &
                t.createdAt.isBiggerOrEqualValue(start) &
                t.createdAt.isSmallerThanValue(end),
          ))
        .get()
        .then((list) => list.length);
  }

  //, , Tasks, , 
  Stream<List<Task>> watchTasksForUser(int ownerUserId, {String? status, bool? upcoming}) {
    final query = select(tasks)
      ..where((t) => t.ownerUserId.equals(ownerUserId))
      ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]);
    if (status != null && status.isNotEmpty && status != 'all') {
      if (status == 'completed') {
        query.where((t) => t.ownerUserId.equals(ownerUserId) & t.completed.equals(true));
      } else if (status == 'pending') {
        query.where((t) => t.ownerUserId.equals(ownerUserId) & t.completed.equals(false));
      }
    }
    if (upcoming == true) {
      final week = DateTime.now().add(const Duration(days: 7));
      query.where(
        (t) =>
            t.ownerUserId.equals(ownerUserId) &
            t.completed.equals(false) &
            t.dueDate.isNotNull() &
            t.dueDate.isSmallerOrEqualValue(week),
      );
    }
    return query.watch();
  }

  Future<Task?> getTaskForUser(int ownerUserId, int id) =>
      (select(tasks)..where((t) => t.id.equals(id) & t.ownerUserId.equals(ownerUserId))).getSingleOrNull();

  Future<int> countPendingTasksForUser(int ownerUserId) => (select(tasks)
        ..where((t) => t.ownerUserId.equals(ownerUserId) & t.completed.equals(false)))
      .get()
      .then((list) => list.length);

  Future<int> countTasksForProjectForUser(int ownerUserId, int projectId) => (select(tasks)
        ..where((t) => t.ownerUserId.equals(ownerUserId) & t.projectId.equals(projectId)))
      .get()
      .then((list) => list.length);

  //, , Expenses, , 
  Stream<List<Expense>> watchExpensesForUser(int ownerUserId, {String? category}) {
    final query = select(expenses)
      ..where((t) => t.ownerUserId.equals(ownerUserId))
      ..orderBy([(t) => OrderingTerm.desc(t.expenseDate)]);
    if (category != null && category.isNotEmpty && category != 'all') {
      query.where((t) => t.ownerUserId.equals(ownerUserId) & t.category.equals(category));
    }
    return query.watch();
  }

  Future<double> sumExpensesForUser(int ownerUserId, {DateTime? since}) async {
    final query = select(expenses)..where((t) => t.ownerUserId.equals(ownerUserId));
    if (since != null) {
      query.where((t) => t.ownerUserId.equals(ownerUserId) & t.expenseDate.isBiggerOrEqualValue(since));
    }
    final rows = await query.get();
    return rows.fold<double>(0, (sum, e) => sum + e.amount);
  }

  //, , Notes, , 
  Stream<List<Note>> watchNotesForUser(int ownerUserId, {String? type}) {
    final query = select(notes)
      ..where((t) => t.ownerUserId.equals(ownerUserId))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (type != null && type.isNotEmpty && type != 'all') {
      query.where((t) => t.ownerUserId.equals(ownerUserId) & t.type.equals(type));
    }
    return query.watch();
  }

  //, , Per-user settings, , 
  Stream<BusinessProfile> watchBusinessProfileForUser(int userId) {
    return customSelect(
      'SELECT user_id FROM business_profiles WHERE user_id = ?',
      variables: [Variable<int>(userId)],
      readsFrom: {businessProfiles},
    ).watch().asyncMap((_) => getOrCreateBusinessProfile(userId));
  }

  Future<BusinessProfile> getOrCreateBusinessProfile(int userId) async {
    await repairUserDefaultsNulls(userId);
    try {
      final existing = await (select(businessProfiles)..where((t) => t.userId.equals(userId))).getSingleOrNull();
      if (existing != null) return existing;
    } catch (e) {
      debugPrint('getOrCreateBusinessProfile read: $e');
    }
    try {
      await into(businessProfiles).insertOnConflictUpdate(
        defaultBusinessProfileCompanion(userId),
      );
    } catch (e) {
      debugPrint('getOrCreateBusinessProfile insert: $e');
    }
    await repairUserDefaultsNulls(userId);
    try {
      final created = await (select(businessProfiles)..where((t) => t.userId.equals(userId))).getSingleOrNull();
      if (created != null) return created;
    } catch (e) {
      debugPrint('getOrCreateBusinessProfile re-read: $e');
    }
    return BusinessProfile(
      userId: userId,
      businessName: '',
      businessEmail: '',
      businessPhone: '',
      ownerName: '',
      businessAddress: '',
      businessCity: '',
      businessPostalCode: '',
      businessCountry: '',
      skills: '[]',
      bio: '',
      clientCompany: '',
      clientIndustry: '',
      clientWebsite: '',
      memberSince: DateTime.now(),
    );
  }

  Future<void> saveBusinessProfileForUser(int userId, BusinessProfilesCompanion entry) async {
    await into(businessProfiles).insertOnConflictUpdate(
      entry.copyWith(userId: Value(userId)),
    );
  }

  Stream<InvoiceBranding> watchInvoiceBrandingForUser(int userId) {
    return customSelect(
      'SELECT user_id FROM invoice_brandings WHERE user_id = ?',
      variables: [Variable<int>(userId)],
      readsFrom: {invoiceBrandings},
    ).watch().asyncMap((_) => getOrCreateInvoiceBranding(userId));
  }

  Future<InvoiceBranding> getOrCreateInvoiceBranding(int userId) async {
    await repairUserDefaultsNulls(userId);
    try {
      final existing = await (select(invoiceBrandings)..where((t) => t.userId.equals(userId))).getSingleOrNull();
      if (existing != null) return existing;
    } catch (e) {
      debugPrint('getOrCreateInvoiceBranding read: $e');
    }
    try {
      await into(invoiceBrandings).insertOnConflictUpdate(
        defaultInvoiceBrandingCompanion(userId),
      );
    } catch (e) {
      debugPrint('getOrCreateInvoiceBranding insert: $e');
    }
    await repairUserDefaultsNulls(userId);
    try {
      final created = await (select(invoiceBrandings)..where((t) => t.userId.equals(userId))).getSingleOrNull();
      if (created != null) return created;
    } catch (e) {
      debugPrint('getOrCreateInvoiceBranding re-read: $e');
    }
    return InvoiceBranding(
      userId: userId,
      accentColor: '#6C63FF',
      templateStyle: 'classic',
      showLogo: true,
    );
  }

  Future<void> saveInvoiceBrandingForUser(int userId, InvoiceBrandingsCompanion entry) async {
    await into(invoiceBrandings).insertOnConflictUpdate(
      entry.copyWith(userId: Value(userId)),
    );
  }

  Stream<AppSettingsTableData> watchAppSettingsForUser(int userId) {
    return customSelect(
      'SELECT user_id FROM app_settings_table WHERE user_id = ?',
      variables: [Variable<int>(userId)],
      readsFrom: {appSettingsTable},
    ).watch().asyncMap((_) async {
      await getOrCreateAppSettings(userId);
      try {
        final settings = await (select(appSettingsTable)..where((t) => t.userId.equals(userId)))
            .getSingleOrNull();
        if (settings != null) return settings;
      } catch (e) {
        debugPrint('watchAppSettingsForUser read: $e');
      }
      return AppSettingsTableData(
        userId: userId,
        themeMode: 'light',
        currency: 'USD',
        timezone: 'UTC',
        subscriptionPlan: 'free',
      );
    });
  }

  Future<void> getOrCreateAppSettings(int userId) async {
    await repairUserDefaultsNulls(userId);
    final existing = await (select(appSettingsTable)..where((t) => t.userId.equals(userId))).getSingleOrNull();
    if (existing != null) return;
    await into(appSettingsTable).insertOnConflictUpdate(
      defaultAppSettingsCompanion(userId),
    );
  }

  Future<void> saveAppSettingsForUser(int userId, AppSettingsTableCompanion entry) async {
    await into(appSettingsTable).insertOnConflictUpdate(
      entry.copyWith(userId: Value(userId)),
    );
  }

  //, , Templates & contracts, , 
  Stream<List<MessageTemplate>> watchMessageTemplatesForUser(int ownerUserId, {String? category}) {
    final query = select(messageTemplates)
      ..where((t) => t.ownerUserId.equals(ownerUserId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (category != null && category.isNotEmpty && category != 'all') {
      query.where((t) => t.ownerUserId.equals(ownerUserId) & t.category.equals(category));
    }
    return query.watch();
  }

  Stream<List<Contract>> watchContractsForUser(int ownerUserId, {String? status}) {
    final query = select(contracts)
      ..where((t) => t.ownerUserId.equals(ownerUserId))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (status != null && status.isNotEmpty && status != 'all') {
      query.where((t) => t.ownerUserId.equals(ownerUserId) & t.status.equals(status));
    }
    return query.watch();
  }

  Future<Contract?> getContractForUser(int ownerUserId, int contractId) {
    return (select(contracts)
          ..where((t) => t.ownerUserId.equals(ownerUserId) & t.id.equals(contractId)))
        .getSingleOrNull();
  }

  //, , Milestones, , 
  Stream<List<ProjectMilestone>> watchMilestonesForProject(int ownerUserId, int projectId) {
    return (select(projectMilestones)
          ..where((t) => t.ownerUserId.equals(ownerUserId) & t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.id)]))
        .watch();
  }

  Stream<List<ProjectMilestone>> watchMilestonesForOwner(int ownerUserId) {
    return (select(projectMilestones)
          ..where((t) => t.ownerUserId.equals(ownerUserId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Future<ProjectMilestone?> getMilestoneForUser(int ownerUserId, int milestoneId) {
    return (select(projectMilestones)
          ..where((t) => t.ownerUserId.equals(ownerUserId) & t.id.equals(milestoneId)))
        .getSingleOrNull();
  }

  //, , Reviews, , 
  Stream<List<ProjectReview>> watchReviewsForOwner(int ownerUserId) {
    return (select(projectReviews)
          ..where((t) => t.ownerUserId.equals(ownerUserId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Stream<List<ProjectReview>> watchReviewsForProject(int ownerUserId, int projectId) {
    return (select(projectReviews)
          ..where((t) => t.ownerUserId.equals(ownerUserId) & t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  //, , Disputes, , 
  Stream<List<InvoiceDispute>> watchDisputesForOwner(int ownerUserId) {
    return (select(invoiceDisputes)
          ..where((t) => t.ownerUserId.equals(ownerUserId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Stream<List<InvoiceDispute>> watchDisputesForInvoice(int ownerUserId, int invoiceId) {
    return (select(invoiceDisputes)
          ..where((t) => t.ownerUserId.equals(ownerUserId) & t.invoiceId.equals(invoiceId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  //, , Tracking, , 
  Stream<List<TrackingEvent>> watchTrackingEventsForUser({
    required int ownerUserId,
    required String entityType,
    required int entityId,
  }) {
    return (select(trackingEvents)
          ..where(
            (t) =>
                t.ownerUserId.equals(ownerUserId) &
                t.entityType.equals(entityType) &
                t.entityId.equals(entityId),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  //, , Time tracking, , 
  Future<ProjectTimeEntry?> getActiveTimeEntryForUser(int ownerUserId) =>
      (select(projectTimeEntries)
            ..where((t) => t.ownerUserId.equals(ownerUserId) & t.endedAt.isNull()))
          .getSingleOrNull();

  Future<int> startTimeEntryForUser(int ownerUserId, int projectId) async {
    final active = await getActiveTimeEntryForUser(ownerUserId);
    if (active != null) await stopTimeEntry(active.id);
    return into(projectTimeEntries).insert(
      ProjectTimeEntriesCompanion.insert(
        ownerUserId: ownerUserId,
        projectId: projectId,
        startedAt: DateTime.now(),
      ),
    );
  }

  Future<int> totalSecondsForProjectForUser(int ownerUserId, int projectId) async {
    final entries = await (select(projectTimeEntries)
          ..where((t) => t.ownerUserId.equals(ownerUserId) & t.projectId.equals(projectId)))
        .get();
    var total = 0;
    final now = DateTime.now();
    for (final e in entries) {
      if (e.endedAt != null) {
        total += e.durationSeconds;
      } else {
        total += now.difference(e.startedAt).inSeconds;
      }
    }
    return total;
  }

  Stream<Map<int, int>> watchAllProjectTrackedSecondsForUser(int ownerUserId) {
    return (select(projectTimeEntries)..where((t) => t.ownerUserId.equals(ownerUserId))).watch().map((entries) {
      final totals = <int, int>{};
      for (final e in entries) {
        if (e.endedAt != null) {
          totals[e.projectId] = (totals[e.projectId] ?? 0) + e.durationSeconds;
        }
      }
      return totals;
    });
  }

  Stream<List<ProjectTimeEntry>> watchProjectTimeEntriesForUser(int ownerUserId, int projectId) {
    return (select(projectTimeEntries)
          ..where((t) => t.ownerUserId.equals(ownerUserId) & t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .watch();
  }

  //, , Client portal (shared projects), , 
  Future<void> linkProjectToClientEmail({
    required int projectId,
    required int freelancerUserId,
    required String clientEmail,
  }) async {
    final email = clientEmail.trim().toLowerCase();
    if (email.isEmpty) return;
    final clientUser = await getUserByEmail(email);
    final existing = await (select(projectClientLinks)
          ..where((t) => t.projectId.equals(projectId) & t.clientEmail.equals(email)))
        .getSingleOrNull();
    if (existing != null) {
      if (clientUser != null && existing.clientUserId == null) {
        await (update(projectClientLinks)..where((t) => t.id.equals(existing.id))).write(
          ProjectClientLinksCompanion(clientUserId: Value(clientUser.id)),
        );
      }
      return;
    }
    await into(projectClientLinks).insert(
      ProjectClientLinksCompanion.insert(
        projectId: projectId,
        freelancerUserId: freelancerUserId,
        clientEmail: email,
        clientUserId: Value(clientUser?.id),
      ),
    );
  }

  Future<void> sendClientMessage({
    required int fromUserId,
    required int toUserId,
    required String body,
    String subject = '',
    int? projectId,
  }) async {
    await into(clientMessages).insert(
      ClientMessagesCompanion.insert(
        fromUserId: fromUserId,
        toUserId: toUserId,
        subject: Value(subject),
        body: body,
        projectId: Value(projectId),
      ),
    );
  }

  Stream<List<ClientMessage>> watchInboxForUser(int userId) {
    return (select(clientMessages)
          ..where((t) => t.toUserId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Stream<List<ClientMessage>> watchSentByUser(int userId) {
    return (select(clientMessages)
          ..where((t) => t.fromUserId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<int> countUnreadMessages(int userId) async {
    final rows = await (select(clientMessages)
          ..where((t) => t.toUserId.equals(userId) & t.isRead.equals(false)))
        .get();
    return rows.length;
  }

  Future<void> markMessageRead(int messageId) async {
    await (update(clientMessages)..where((t) => t.id.equals(messageId))).write(
      const ClientMessagesCompanion(isRead: Value(true)),
    );
  }

  Future<void> markAllMessagesRead(int userId) async {
    await (update(clientMessages)..where((t) => t.toUserId.equals(userId))).write(
      const ClientMessagesCompanion(isRead: Value(true)),
    );
  }

  //, , Team members, , 
  Stream<List<TeamMember>> watchTeamMembers(int ownerUserId) {
    return (select(teamMembers)
          ..where((t) => t.ownerUserId.equals(ownerUserId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<int> insertTeamMember(TeamMembersCompanion entry) => into(teamMembers).insert(entry);

  Future<int> deleteTeamMember(int id) =>
      (delete(teamMembers)..where((t) => t.id.equals(id))).go();

  Future<List<Invoice>> watchInvoicesForClient(int clientUserId) async {
    return watchInvoicesForClientStream(clientUserId).first;
  }

  Stream<List<Invoice>> watchInvoicesForClientStream(int clientUserId) async* {
    await for (final projects in watchProjectsForClient(clientUserId)) {
      if (projects.isEmpty) {
        yield [];
        continue;
      }
      final projectIds = projects.map((p) => p.id).toSet();
      final links = await getFreelancerLinksForClient(clientUserId);
      if (links.isEmpty) {
        yield [];
        continue;
      }
      final freelancerIds = links.map((l) => l.freelancerUserId).toSet();
      final invoices = <Invoice>[];
      for (final freelancerId in freelancerIds) {
        final all = await watchInvoicesForUser(freelancerId).first;
        invoices.addAll(
          all.where((inv) => inv.projectId != null && projectIds.contains(inv.projectId)),
        );
      }
      invoices.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      yield invoices;
    }
  }

  Future<User?> getFreelancerUserForClientInvoice(int clientUserId, Invoice invoice) async {
    if (invoice.projectId == null) return null;
    return getFreelancerUserForClientProject(clientUserId, invoice.projectId!);
  }

  Stream<List<Contract>> watchContractsForClient(int clientUserId) async* {
    await for (final links
        in (select(projectClientLinks)..where((t) => t.clientUserId.equals(clientUserId))).watch()) {
      final results = <Contract>[];
      final seen = <int>{};
      for (final link in links) {
        final project = await (select(projects)..where((t) => t.id.equals(link.projectId))).getSingleOrNull();
        if (project == null) continue;
        final rows = await (select(contracts)
              ..where(
                (t) =>
                    t.ownerUserId.equals(link.freelancerUserId) &
                    t.customerId.equals(project.customerId) &
                    t.status.equals('draft').not(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
            .get();
        for (final c in rows) {
          if (seen.add(c.id)) results.add(c);
        }
      }
      results.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      yield results;
    }
  }

  Stream<List<ProjectTimeEntry>> watchTimeEntriesForClientProject(int clientUserId, int projectId) async* {
    await for (final links
        in (select(projectClientLinks)..where((t) => t.clientUserId.equals(clientUserId))).watch()) {
      final link = links.where((l) => l.projectId == projectId).firstOrNull;
      if (link == null) {
        yield [];
        continue;
      }
      yield* (select(projectTimeEntries)
            ..where((t) => t.projectId.equals(projectId) & t.ownerUserId.equals(link.freelancerUserId)))
          .watch();
    }
  }

  Future<int> countMessageTemplatesForUser(int ownerUserId) {
    return (select(messageTemplates)..where((t) => t.ownerUserId.equals(ownerUserId))).get().then((l) => l.length);
  }

  Future<List<ProjectClientLink>> getFreelancerLinksForClient(int clientUserId) {
    return (select(projectClientLinks)..where((t) => t.clientUserId.equals(clientUserId))).get();
  }

  Future<ProjectClientLink?> getClientLinkForProject(int clientUserId, int projectId) {
    return (select(projectClientLinks)
          ..where((t) => t.clientUserId.equals(clientUserId) & t.projectId.equals(projectId)))
        .getSingleOrNull();
  }

  Future<User?> getFreelancerUserForClientProject(int clientUserId, int projectId) async {
    final link = await getClientLinkForProject(clientUserId, projectId);
    if (link == null) return null;
    return getUser(link.freelancerUserId);
  }

  Future<void> linkPendingClientsForUser(int clientUserId, String email) async {
    final normalized = email.trim().toLowerCase();
    await (update(projectClientLinks)..where((t) => t.clientEmail.equals(normalized))).write(
      ProjectClientLinksCompanion(clientUserId: Value(clientUserId)),
    );
  }

  Stream<List<Project>> watchProjectsForClient(int clientUserId) async* {
    await for (final links
        in (select(projectClientLinks)..where((t) => t.clientUserId.equals(clientUserId))).watch()) {
      final result = <Project>[];
      for (final link in links) {
        final project = await (select(projects)..where((t) => t.id.equals(link.projectId))).getSingleOrNull();
        if (project != null) result.add(project);
      }
      result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      yield result;
    }
  }

  Future<List<ProjectTimeEntry>> getTimeEntriesForClientProject(int clientUserId, int projectId) async {
    final link = await (select(projectClientLinks)
          ..where((t) => t.clientUserId.equals(clientUserId) & t.projectId.equals(projectId)))
        .getSingleOrNull();
    if (link == null) return [];
    return (select(projectTimeEntries)
          ..where((t) => t.projectId.equals(projectId) & t.ownerUserId.equals(link.freelancerUserId)))
        .get();
  }

  Stream<List<TrackingEvent>> watchTrackingForClientProject({
    required int clientUserId,
    required int projectId,
  }) async* {
    await for (final links
        in (select(projectClientLinks)..where((t) => t.clientUserId.equals(clientUserId))).watch()) {
      final link = links.where((l) => l.projectId == projectId).firstOrNull;
      if (link == null) {
        yield [];
        continue;
      }
      final events = await (select(trackingEvents)
            ..where(
              (t) =>
                  t.ownerUserId.equals(link.freelancerUserId) &
                  t.entityType.equals('project') &
                  t.entityId.equals(projectId),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
      yield events;
    }
  }

  //, , Products, , 
  Stream<List<Product>> watchProductsForUser(int ownerUserId, {bool activeOnly = false}) {
    final q = select(products)
      ..where((t) => t.ownerUserId.equals(ownerUserId))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (activeOnly) {
      q.where((t) => t.ownerUserId.equals(ownerUserId) & t.isActive.equals(true));
    }
    return q.watch();
  }

  Future<Product?> getProductForUser(int ownerUserId, int id) =>
      (select(products)..where((t) => t.id.equals(id) & t.ownerUserId.equals(ownerUserId))).getSingleOrNull();

  Future<int> insertProduct(ProductsCompanion entry) => into(products).insert(entry);

  Future<bool> updateProduct(Product entry) => update(products).replace(entry);

  Future<int> deleteProductForUser(int ownerUserId, int id) =>
      (delete(products)..where((t) => t.id.equals(id) & t.ownerUserId.equals(ownerUserId))).go();

  //, , Quotes, , 
  Stream<List<Quote>> watchQuotesForUser(int ownerUserId, {String? status}) {
    final q = select(quotes)
      ..where((t) => t.ownerUserId.equals(ownerUserId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (status != null && status.isNotEmpty && status != 'all') {
      q.where((t) => t.ownerUserId.equals(ownerUserId) & t.status.equals(status));
    }
    return q.watch();
  }

  Future<Quote?> getQuoteForUser(int ownerUserId, int id) =>
      (select(quotes)..where((t) => t.id.equals(id) & t.ownerUserId.equals(ownerUserId))).getSingleOrNull();

  Future<int> insertQuote(QuotesCompanion entry) => into(quotes).insert(entry);

  Future<bool> updateQuote(Quote entry) => update(quotes).replace(entry);

  Future<int> deleteQuoteForUser(int ownerUserId, int id) =>
      (delete(quotes)..where((t) => t.id.equals(id) & t.ownerUserId.equals(ownerUserId))).go();

  //, , Recurring invoices, , 
  Stream<List<RecurringInvoice>> watchRecurringInvoicesForUser(int ownerUserId) {
    return (select(recurringInvoices)
          ..where((t) => t.ownerUserId.equals(ownerUserId))
          ..orderBy([(t) => OrderingTerm.asc(t.nextRunAt)]))
        .watch();
  }

  Future<RecurringInvoice?> getRecurringInvoiceForUser(int ownerUserId, int id) =>
      (select(recurringInvoices)..where((t) => t.id.equals(id) & t.ownerUserId.equals(ownerUserId)))
          .getSingleOrNull();

  Future<int> insertRecurringInvoice(RecurringInvoicesCompanion entry) =>
      into(recurringInvoices).insert(entry);

  Future<bool> updateRecurringInvoice(RecurringInvoice entry) =>
      update(recurringInvoices).replace(entry);

  Future<int> deleteRecurringInvoiceForUser(int ownerUserId, int id) =>
      (delete(recurringInvoices)..where((t) => t.id.equals(id) & t.ownerUserId.equals(ownerUserId))).go();

  Future<List<RecurringInvoice>> dueRecurringInvoicesForUser(int ownerUserId, DateTime asOf) {
    return (select(recurringInvoices)
          ..where(
            (t) =>
                t.ownerUserId.equals(ownerUserId) &
                t.isActive.equals(true) &
                t.nextRunAt.isSmallerOrEqualValue(asOf),
          ))
        .get();
  }

  //, , Vendors, , 
  Stream<List<Vendor>> watchVendorsForUser(int ownerUserId) {
    return (select(vendors)
          ..where((t) => t.ownerUserId.equals(ownerUserId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<Vendor?> getVendorForUser(int ownerUserId, int id) =>
      (select(vendors)..where((t) => t.id.equals(id) & t.ownerUserId.equals(ownerUserId))).getSingleOrNull();

  Future<int> insertVendor(VendorsCompanion entry) => into(vendors).insert(entry);

  Future<bool> updateVendor(Vendor entry) => update(vendors).replace(entry);

  Future<int> deleteVendorForUser(int ownerUserId, int id) =>
      (delete(vendors)..where((t) => t.id.equals(id) & t.ownerUserId.equals(ownerUserId))).go();

  //, , Purchase orders, , 
  Stream<List<PurchaseOrder>> watchPurchaseOrdersForUser(int ownerUserId) {
    return (select(purchaseOrders)
          ..where((t) => t.ownerUserId.equals(ownerUserId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<PurchaseOrder?> getPurchaseOrderForUser(int ownerUserId, int id) =>
      (select(purchaseOrders)..where((t) => t.id.equals(id) & t.ownerUserId.equals(ownerUserId)))
          .getSingleOrNull();

  Future<int> insertPurchaseOrder(PurchaseOrdersCompanion entry) => into(purchaseOrders).insert(entry);

  Future<bool> updatePurchaseOrder(PurchaseOrder entry) => update(purchaseOrders).replace(entry);

  //, , Credits, , 
  Stream<List<Credit>> watchCreditsForUser(int ownerUserId) {
    return (select(credits)
          ..where((t) => t.ownerUserId.equals(ownerUserId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<Credit?> getCreditForUser(int ownerUserId, int id) =>
      (select(credits)..where((t) => t.id.equals(id) & t.ownerUserId.equals(ownerUserId))).getSingleOrNull();

  Future<int> insertCredit(CreditsCompanion entry) => into(credits).insert(entry);

  Future<bool> updateCredit(Credit entry) => update(credits).replace(entry);

  Future<double> openCreditBalanceForCustomer(int ownerUserId, int customerId) async {
    final rows = await (select(credits)
          ..where(
            (t) =>
                t.ownerUserId.equals(ownerUserId) &
                t.customerId.equals(customerId) &
                t.status.equals('open'),
          ))
        .get();
    return rows.fold<double>(0, (s, c) => s + c.balance);
  }

  //, , Invoice payments, , 
  Stream<List<InvoicePayment>> watchPaymentsForUser(int ownerUserId) {
    return (select(invoicePayments)
          ..where((t) => t.ownerUserId.equals(ownerUserId))
          ..orderBy([(t) => OrderingTerm.desc(t.paidAt)]))
        .watch();
  }

  Stream<List<InvoicePayment>> watchPaymentsForInvoice(int ownerUserId, int invoiceId) {
    return (select(invoicePayments)
          ..where((t) => t.ownerUserId.equals(ownerUserId) & t.invoiceId.equals(invoiceId))
          ..orderBy([(t) => OrderingTerm.desc(t.paidAt)]))
        .watch();
  }

  Future<int> insertInvoicePayment(InvoicePaymentsCompanion entry) =>
      into(invoicePayments).insert(entry);

  Future<List<Expense>> billableExpensesForUser(int ownerUserId, {int? customerId}) {
    final q = select(expenses)
      ..where(
        (t) =>
            t.ownerUserId.equals(ownerUserId) &
            t.isBillable.equals(true) &
            t.isInvoiced.equals(false),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.expenseDate)]);
    if (customerId != null) {
      q.where(
        (t) =>
            t.ownerUserId.equals(ownerUserId) &
            t.isBillable.equals(true) &
            t.isInvoiced.equals(false) &
            t.customerId.equals(customerId),
      );
    }
    return q.get();
  }
}
