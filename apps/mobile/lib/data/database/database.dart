import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';
import 'user_defaults.dart';
import 'user_scoped_queries.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Customers,
    Projects,
    Invoices,
    BusinessProfiles,
    InvoiceBrandings,
    AppSettingsTable,
    Tasks,
    Expenses,
    Notes,
    MessageTemplates,
    Contracts,
    AppAnalytics,
    TrackingEvents,
    ProjectTimeEntries,
    ProjectClientLinks,
    ClientMessages,
    TeamMembers,
    FileAttachments,
    CalendarReminders,
    ProjectMilestones,
    ProjectReviews,
    InvoiceDisputes,
    Products,
    Quotes,
    RecurringInvoices,
    Vendors,
    PurchaseOrders,
    Credits,
    InvoicePayments,
    SyncOutboxEntries,
    SyncConflictEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 18;

  bool _databaseRepaired = false;

  Future<void> _ensureDatabaseRepaired() async {
    if (_databaseRepaired) return;
    await repairAllDatabaseNulls();
    _databaseRepaired = true;
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await repairAllDatabaseNulls();
          _databaseRepaired = true;
        },
        onCreate: (Migrator m) async {
          await m.createAll();
          await _seedDefaults();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(tasks);
            await m.createTable(expenses);
            await m.createTable(notes);
          }
          if (from < 3) {
            await m.createTable(users);
            await m.addColumn(businessProfiles, businessProfiles.ownerPhotoPath);
          }
          if (from < 4) {
            await m.addColumn(customers, customers.city);
            await m.addColumn(customers, customers.postalCode);
            await m.addColumn(businessProfiles, businessProfiles.businessAddress);
            await m.addColumn(businessProfiles, businessProfiles.businessCity);
            await m.addColumn(businessProfiles, businessProfiles.businessPostalCode);
            await m.addColumn(businessProfiles, businessProfiles.businessCountry);
            await m.createTable(messageTemplates);
            await m.createTable(contracts);
          }
          if (from < 5) {
            await m.addColumn(users, users.role);
            await m.createTable(appAnalytics);
          }
          if (from < 6) {
            await m.createTable(trackingEvents);
          }
          if (from < 7) {
            await m.createTable(projectTimeEntries);
          }
          if (from < 8) {
            await _migrateToV8(m);
          }
          if (from < 9) {
            await _migrateToV9();
          }
          if (from < 10) {
            await _migrateToV10();
          }
          if (from < 11) {
            await repairAllDatabaseNulls();
          }
          if (from < 12) {
            await m.createTable(clientMessages);
            await m.createTable(teamMembers);
          }
          if (from < 13) {
            await repairAllDatabaseNulls();
          }
          if (from < 14) {
            await m.createTable(fileAttachments);
            await m.createTable(calendarReminders);
          }
          if (from < 15) {
            await m.addColumn(businessProfiles, businessProfiles.skills);
            await m.addColumn(businessProfiles, businessProfiles.bio);
            await m.addColumn(businessProfiles, businessProfiles.clientCompany);
            await m.addColumn(businessProfiles, businessProfiles.clientIndustry);
            await m.addColumn(businessProfiles, businessProfiles.clientWebsite);
          }
          if (from < 16) {
            await m.createTable(projectMilestones);
            await m.createTable(projectReviews);
            await m.createTable(invoiceDisputes);
          }
          if (from < 17) {
            await m.createTable(products);
            await m.createTable(quotes);
            await m.createTable(recurringInvoices);
            await m.createTable(vendors);
            await m.createTable(purchaseOrders);
            await m.createTable(credits);
            await m.createTable(invoicePayments);
            if (!await _columnExists('expenses', 'vendor_id')) {
              await m.addColumn(expenses, expenses.vendorId);
            }
            if (!await _columnExists('expenses', 'is_billable')) {
              await m.addColumn(expenses, expenses.isBillable);
            }
            if (!await _columnExists('expenses', 'is_invoiced')) {
              await m.addColumn(expenses, expenses.isInvoiced);
            }
            if (!await _columnExists('expenses', 'invoice_id')) {
              await m.addColumn(expenses, expenses.invoiceId);
            }
            if (!await _columnExists('invoices', 'amount_paid')) {
              await m.addColumn(invoices, invoices.amountPaid);
            }
            if (!await _columnExists('invoices', 'recurring_invoice_id')) {
              await m.addColumn(invoices, invoices.recurringInvoiceId);
            }
            if (!await _columnExists('invoices', 'quote_id')) {
              await m.addColumn(invoices, invoices.quoteId);
            }
          }
          if (from < 18) {
            await m.createTable(syncOutboxEntries);
            await m.createTable(syncConflictEntries);
          }
        },
      );

  Future<bool> _columnExists(String table, String column) async {
    final rows = await customSelect(
      'PRAGMA table_info($table)',
      readsFrom: {},
    ).get();
    return rows.any((r) => r.read<String>('name') == column);
  }

  Future<void> _migrateToV9() async {
    await _rebuildBusinessProfilesTable();
    await _rebuildInvoiceBrandingsTable();
    await _rebuildAppSettingsTable();
  }

  /// Fix NULL columns that crash Drift reads (null check operator on member_since etc).
  Future<void> _migrateToV10() async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await customStatement('''
      UPDATE business_profiles SET member_since = $nowSec WHERE member_since IS NULL
    ''');
    await customStatement('''
      UPDATE business_profiles SET business_name = '' WHERE business_name IS NULL
    ''');
    await customStatement('''
      UPDATE business_profiles SET business_email = '' WHERE business_email IS NULL
    ''');
    await customStatement('''
      UPDATE business_profiles SET business_phone = '' WHERE business_phone IS NULL
    ''');
    await customStatement('''
      UPDATE business_profiles SET owner_name = '' WHERE owner_name IS NULL
    ''');
    await customStatement('''
      UPDATE business_profiles SET business_address = '' WHERE business_address IS NULL
    ''');
    await customStatement('''
      UPDATE business_profiles SET business_city = '' WHERE business_city IS NULL
    ''');
    await customStatement('''
      UPDATE business_profiles SET business_postal_code = '' WHERE business_postal_code IS NULL
    ''');
    await customStatement('''
      UPDATE business_profiles SET business_country = '' WHERE business_country IS NULL
    ''');
    await customStatement('''
      UPDATE invoice_brandings SET accent_color = '#6C63FF' WHERE accent_color IS NULL
    ''');
    await customStatement('''
      UPDATE invoice_brandings SET template_style = 'classic' WHERE template_style IS NULL
    ''');
    await customStatement('''
      UPDATE invoice_brandings SET show_logo = 1 WHERE show_logo IS NULL
    ''');
    await customStatement('''
      UPDATE app_settings_table SET theme_mode = 'light' WHERE theme_mode IS NULL
    ''');
    await customStatement('''
      UPDATE app_settings_table SET currency = 'USD' WHERE currency IS NULL
    ''');
    await customStatement('''
      UPDATE app_settings_table SET timezone = 'UTC' WHERE timezone IS NULL
    ''');
    await customStatement('''
      UPDATE app_settings_table SET subscription_plan = 'free' WHERE subscription_plan IS NULL
    ''');
  }

  Future<void> _rebuildBusinessProfilesTable() async {
    final exists = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='business_profiles'",
      readsFrom: {},
    ).getSingleOrNull();
    if (exists == null) return;

    final hasId = await _columnExists('business_profiles', 'id');
    final hasUserId = await _columnExists('business_profiles', 'user_id');

    await customStatement('''
      CREATE TABLE business_profiles_new (
        user_id INTEGER NOT NULL PRIMARY KEY REFERENCES users(id),
        logo_path TEXT,
        business_name TEXT NOT NULL DEFAULT '',
        business_email TEXT NOT NULL DEFAULT '',
        business_phone TEXT NOT NULL DEFAULT '',
        owner_name TEXT NOT NULL DEFAULT '',
        owner_photo_path TEXT,
        business_address TEXT NOT NULL DEFAULT '',
        business_city TEXT NOT NULL DEFAULT '',
        business_postal_code TEXT NOT NULL DEFAULT '',
        business_country TEXT NOT NULL DEFAULT '',
        member_since INTEGER NOT NULL DEFAULT (CAST(strftime('%s', 'now') AS INTEGER))
      )
    ''');

    if (hasUserId && hasId) {
      await customStatement('''
        INSERT OR IGNORE INTO business_profiles_new (
          user_id, logo_path, business_name, business_email, business_phone,
          owner_name, owner_photo_path, business_address, business_city,
          business_postal_code, business_country, member_since
        )
        SELECT
          COALESCE(NULLIF(user_id, 0), id),
          logo_path, business_name, business_email, business_phone,
          owner_name, owner_photo_path, business_address, business_city,
          business_postal_code, business_country, member_since
        FROM business_profiles
      ''');
    } else if (hasUserId) {
      await customStatement('''
        INSERT OR IGNORE INTO business_profiles_new (
          user_id, logo_path, business_name, business_email, business_phone,
          owner_name, owner_photo_path, business_address, business_city,
          business_postal_code, business_country, member_since
        )
        SELECT
          user_id, logo_path, business_name, business_email, business_phone,
          owner_name, owner_photo_path, business_address, business_city,
          business_postal_code, business_country, member_since
        FROM business_profiles
        WHERE user_id IS NOT NULL AND user_id > 0
      ''');
    }

    await customStatement('DROP TABLE business_profiles');
    await customStatement('ALTER TABLE business_profiles_new RENAME TO business_profiles');
  }

  Future<void> _rebuildInvoiceBrandingsTable() async {
    final exists = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='invoice_brandings'",
      readsFrom: {},
    ).getSingleOrNull();
    if (exists == null) return;

    final hasId = await _columnExists('invoice_brandings', 'id');
    final hasUserId = await _columnExists('invoice_brandings', 'user_id');

    await customStatement('''
      CREATE TABLE invoice_brandings_new (
        user_id INTEGER NOT NULL PRIMARY KEY REFERENCES users(id),
        accent_color TEXT NOT NULL DEFAULT '#6C63FF',
        template_style TEXT NOT NULL DEFAULT 'classic',
        show_logo INTEGER NOT NULL DEFAULT 1
      )
    ''');

    if (hasUserId && hasId) {
      await customStatement('''
        INSERT OR IGNORE INTO invoice_brandings_new (user_id, accent_color, template_style, show_logo)
        SELECT COALESCE(NULLIF(user_id, 0), id), accent_color, template_style, show_logo
        FROM invoice_brandings
      ''');
    } else if (hasUserId) {
      await customStatement('''
        INSERT OR IGNORE INTO invoice_brandings_new (user_id, accent_color, template_style, show_logo)
        SELECT user_id, accent_color, template_style, show_logo
        FROM invoice_brandings
        WHERE user_id IS NOT NULL AND user_id > 0
      ''');
    }

    await customStatement('DROP TABLE invoice_brandings');
    await customStatement('ALTER TABLE invoice_brandings_new RENAME TO invoice_brandings');
  }

  Future<void> _rebuildAppSettingsTable() async {
    final exists = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='app_settings_table'",
      readsFrom: {},
    ).getSingleOrNull();
    if (exists == null) return;

    final hasId = await _columnExists('app_settings_table', 'id');
    final hasUserId = await _columnExists('app_settings_table', 'user_id');

    await customStatement('''
      CREATE TABLE app_settings_table_new (
        user_id INTEGER NOT NULL PRIMARY KEY REFERENCES users(id),
        theme_mode TEXT NOT NULL DEFAULT 'light',
        currency TEXT NOT NULL DEFAULT 'USD',
        timezone TEXT NOT NULL DEFAULT 'UTC',
        subscription_plan TEXT NOT NULL DEFAULT 'free'
      )
    ''');

    if (hasUserId && hasId) {
      await customStatement('''
        INSERT OR IGNORE INTO app_settings_table_new (user_id, theme_mode, currency, timezone, subscription_plan)
        SELECT COALESCE(NULLIF(user_id, 0), id), theme_mode, currency, timezone, subscription_plan
        FROM app_settings_table
      ''');
    } else if (hasUserId) {
      await customStatement('''
        INSERT OR IGNORE INTO app_settings_table_new (user_id, theme_mode, currency, timezone, subscription_plan)
        SELECT user_id, theme_mode, currency, timezone, subscription_plan
        FROM app_settings_table
        WHERE user_id IS NOT NULL AND user_id > 0
      ''');
    }

    await customStatement('DROP TABLE app_settings_table');
    await customStatement('ALTER TABLE app_settings_table_new RENAME TO app_settings_table');
  }

  Future<void> _migrateToV8(Migrator m) async {
    final firstUser = await (select(users)..limit(1)).getSingleOrNull();
    final owner = firstUser?.id ?? 1;

    await m.addColumn(customers, customers.ownerUserId);
    await customStatement('UPDATE customers SET owner_user_id = $owner');
    await m.addColumn(projects, projects.ownerUserId);
    await customStatement('UPDATE projects SET owner_user_id = $owner');
    await m.addColumn(invoices, invoices.ownerUserId);
    await customStatement('UPDATE invoices SET owner_user_id = $owner');
    await m.addColumn(tasks, tasks.ownerUserId);
    await customStatement('UPDATE tasks SET owner_user_id = $owner');
    await m.addColumn(expenses, expenses.ownerUserId);
    await customStatement('UPDATE expenses SET owner_user_id = $owner');
    await m.addColumn(notes, notes.ownerUserId);
    await customStatement('UPDATE notes SET owner_user_id = $owner');
    await m.addColumn(messageTemplates, messageTemplates.ownerUserId);
    await customStatement('UPDATE message_templates SET owner_user_id = $owner');
    await m.addColumn(contracts, contracts.ownerUserId);
    await customStatement('UPDATE contracts SET owner_user_id = $owner');
    await m.addColumn(trackingEvents, trackingEvents.ownerUserId);
    await customStatement('UPDATE tracking_events SET owner_user_id = $owner');
    await m.addColumn(projectTimeEntries, projectTimeEntries.ownerUserId);
    await customStatement('UPDATE project_time_entries SET owner_user_id = $owner');

    await m.addColumn(users, users.accountType);
    await m.addColumn(users, users.googleId);
    await m.addColumn(users, users.emailVerified);
    await customStatement("UPDATE users SET account_type = 'freelancer' WHERE account_type IS NULL OR account_type = ''");
    await customStatement("UPDATE users SET account_type = 'admin' WHERE role = 'admin'");

    await m.createTable(projectClientLinks);

    await m.addColumn(businessProfiles, businessProfiles.userId);
    await customStatement('UPDATE business_profiles SET user_id = $owner');
    await m.addColumn(invoiceBrandings, invoiceBrandings.userId);
    await customStatement('UPDATE invoice_brandings SET user_id = $owner');
    await m.addColumn(appSettingsTable, appSettingsTable.userId);
    await customStatement('UPDATE app_settings_table SET user_id = $owner');
  }

  Future<void> _seedDefaults() async {
    // Per-user defaults are created on signup via getOrCreate* methods.
  }

  Future<void> seedUserDefaults(int userId) async {
    await safeSeedUserDefaults(userId);
  }

  // Customers
  Stream<List<Customer>> watchCustomers({String? search}) {
    final query = select(customers)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (search != null && search.isNotEmpty) {
      final term = '%$search%';
      query.where(
        (t) =>
            t.contactPerson.like(term) |
            t.company.like(term) |
            t.emails.like(term),
      );
    }
    return query.watch();
  }

  Future<int> countCustomers() => customers.count().getSingle();

  Future<Customer?> getCustomer(int id) =>
      (select(customers)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertCustomer(CustomersCompanion entry) =>
      into(customers).insert(entry);

  Future<bool> updateCustomer(Customer entry) => update(customers).replace(entry);

  Future<int> deleteCustomer(int id) =>
      (delete(customers)..where((t) => t.id.equals(id))).go();

  // Projects
  Stream<List<Project>> watchProjects({String? search, String? status}) {
    final query = select(projects)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (search != null && search.isNotEmpty) {
      final term = '%$search%';
      query.where((t) => t.name.like(term) | t.description.like(term));
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      query.where((t) => t.status.equals(status));
    }
    return query.watch();
  }

  Future<int> countProjects() => projects.count().getSingle();

  Future<int> countActiveProjects() => (select(projects)
        ..where((t) => t.status.equals('in_progress')))
      .get()
      .then((list) => list.length);

  Future<Project?> getProject(int id) =>
      (select(projects)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertProject(ProjectsCompanion entry) =>
      into(projects).insert(entry);

  Future<bool> updateProject(Project entry) => update(projects).replace(entry);

  Future<int> deleteProject(int id) =>
      (delete(projects)..where((t) => t.id.equals(id))).go();

  // Invoices
  Stream<List<Invoice>> watchInvoices({String? status}) {
    final query = select(invoices)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (status != null && status.isNotEmpty && status != 'all') {
      if (status == 'outstanding') {
        query.where(
          (t) => t.status.equals('sent') | t.status.equals('overdue'),
        );
      } else {
        query.where((t) => t.status.equals(status));
      }
    }
    return query.watch();
  }

  Future<int> countInvoicesThisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);
    return (select(invoices)
          ..where(
            (t) =>
                t.createdAt.isBiggerOrEqualValue(start) &
                t.createdAt.isSmallerThanValue(end),
          ))
        .get()
        .then((list) => list.length);
  }

  Future<double> sumOutstanding() async {
    final rows = await (select(invoices)
          ..where(
            (t) => t.status.equals('sent') | t.status.equals('overdue'),
          ))
        .get();
    return rows.fold<double>(0, (sum, i) => sum + i.total);
  }

  Future<double> sumPaid() async {
    final rows = await (select(invoices)
          ..where((t) => t.status.equals('paid')))
        .get();
    return rows.fold<double>(0, (sum, i) => sum + i.total);
  }

  Future<double> sumTotalInvoiced() async {
    final rows = await select(invoices).get();
    return rows.fold<double>(0, (sum, i) => sum + i.total);
  }

  Future<double> sumExpenses({DateTime? since}) async {
    final query = select(expenses);
    if (since != null) {
      query.where((t) => t.expenseDate.isBiggerOrEqualValue(since));
    }
    final rows = await query.get();
    return rows.fold<double>(0, (sum, e) => sum + e.amount);
  }

  Future<Invoice?> getInvoice(int id) =>
      (select(invoices)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertInvoice(InvoicesCompanion entry) =>
      into(invoices).insert(entry);

  Future<bool> updateInvoice(Invoice entry) => update(invoices).replace(entry);

  Future<int> deleteInvoice(int id) =>
      (delete(invoices)..where((t) => t.id.equals(id))).go();

  // Tasks
  Stream<List<Task>> watchTasks({String? status, bool? upcoming}) {
    final query = select(tasks)..orderBy([(t) => OrderingTerm.asc(t.dueDate)]);
    if (status != null && status.isNotEmpty && status != 'all') {
      if (status == 'completed') {
        query.where((t) => t.completed.equals(true));
      } else if (status == 'pending') {
        query.where((t) => t.completed.equals(false));
      }
    }
    if (upcoming == true) {
      final now = DateTime.now();
      final week = now.add(const Duration(days: 7));
      query.where(
        (t) =>
            t.completed.equals(false) &
            t.dueDate.isNotNull() &
            t.dueDate.isSmallerOrEqualValue(week),
      );
    }
    return query.watch();
  }

  Future<Task?> getTask(int id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertTask(TasksCompanion entry) => into(tasks).insert(entry);

  Future<bool> updateTask(Task entry) => update(tasks).replace(entry);

  Future<int> deleteTask(int id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  Future<int> countPendingTasks() => (select(tasks)
        ..where((t) => t.completed.equals(false)))
      .get()
      .then((list) => list.length);

  // Expenses
  Stream<List<Expense>> watchExpenses({String? category}) {
    final query = select(expenses)
      ..orderBy([(t) => OrderingTerm.desc(t.expenseDate)]);
    if (category != null && category.isNotEmpty && category != 'all') {
      query.where((t) => t.category.equals(category));
    }
    return query.watch();
  }

  Future<Expense?> getExpense(int id) =>
      (select(expenses)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertExpense(ExpensesCompanion entry) =>
      into(expenses).insert(entry);

  Future<bool> updateExpense(Expense entry) => update(expenses).replace(entry);

  Future<int> deleteExpense(int id) =>
      (delete(expenses)..where((t) => t.id.equals(id))).go();

  // Notes
  Stream<List<Note>> watchNotes({String? type}) {
    final query = select(notes)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (type != null && type.isNotEmpty && type != 'all') {
      query.where((t) => t.type.equals(type));
    }
    return query.watch();
  }

  Future<Note?> getNote(int id) =>
      (select(notes)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertNote(NotesCompanion entry) => into(notes).insert(entry);

  Future<bool> updateNote(Note entry) => update(notes).replace(entry);

  Future<int> deleteNote(int id) =>
      (delete(notes)..where((t) => t.id.equals(id))).go();

  // Singletons
  Stream<BusinessProfile> watchBusinessProfile() =>
      select(businessProfiles).watchSingle();

  Future<void> saveBusinessProfile(BusinessProfilesCompanion entry) async {
    await into(businessProfiles).insertOnConflictUpdate(entry);
  }

  Stream<InvoiceBranding> watchInvoiceBranding() =>
      select(invoiceBrandings).watchSingle();

  Future<void> saveInvoiceBranding(InvoiceBrandingsCompanion entry) async {
    await into(invoiceBrandings).insertOnConflictUpdate(entry);
  }

  Stream<AppSettingsTableData> watchAppSettings() =>
      select(appSettingsTable).watchSingle();

  Future<void> saveAppSettings(AppSettingsTableCompanion entry) async {
    await into(appSettingsTable).insertOnConflictUpdate(entry);
  }

  // Users / Auth
  Future<User?> getUserByEmail(String email) async {
    await _ensureDatabaseRepaired();
    return (select(users)..where((t) => t.email.equals(email.toLowerCase().trim())))
        .getSingleOrNull();
  }

  Future<User?> getUser(int id) async {
    await _ensureDatabaseRepaired();
    return (select(users)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertUser(UsersCompanion entry) => insertUserSafe(entry);

  Future<bool> updateUser(User entry) => update(users).replace(entry);

  // Message templates
  Stream<List<MessageTemplate>> watchMessageTemplates({String? category}) {
    final query = select(messageTemplates)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (category != null && category.isNotEmpty && category != 'all') {
      query.where((t) => t.category.equals(category));
    }
    return query.watch();
  }

  Future<int> countMessageTemplates() => messageTemplates.count().getSingle();

  Future<int> insertMessageTemplate(MessageTemplatesCompanion entry) =>
      into(messageTemplates).insert(entry);

  Future<int> deleteMessageTemplate(int id) =>
      (delete(messageTemplates)..where((t) => t.id.equals(id))).go();

  // Contracts
  Stream<List<Contract>> watchContracts({String? status}) {
    final query = select(contracts)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (status != null && status.isNotEmpty && status != 'all') {
      query.where((t) => t.status.equals(status));
    }
    return query.watch();
  }

  Future<int> countContracts({String? status}) async {
    final query = select(contracts);
    if (status != null && status.isNotEmpty) {
      query.where((t) => t.status.equals(status));
    }
    return query.get().then((list) => list.length);
  }

  Future<int> insertContract(ContractsCompanion entry) =>
      into(contracts).insert(entry);

  Future<bool> updateContract(Contract entry) => update(contracts).replace(entry);

  Future<int> deleteContract(int id) =>
      (delete(contracts)..where((t) => t.id.equals(id))).go();

  // Analytics
  Future<int> insertAnalytics(AppAnalyticsCompanion entry) =>
      into(appAnalytics).insert(entry);

  Stream<List<AppAnalytic>> watchAnalytics({int limit = 100}) {
    return (select(appAnalytics)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .watch();
  }

  Future<int> countAnalyticsByEvent(String eventType) async {
    final rows = await (select(appAnalytics)..where((t) => t.eventType.equals(eventType))).get();
    return rows.length;
  }

  Future<int> countProUsers() async {
    final rows = await (select(appAnalytics)..where((t) => t.eventType.equals('pro_activate'))).get();
    return rows.length;
  }

  Future<List<AppAnalytic>> getUnsyncedAnalytics() async {
    return (select(appAnalytics)..where((t) => t.synced.equals(false))).get();
  }

  Future<void> markAnalyticsSynced(int id) async {
    await (update(appAnalytics)..where((t) => t.id.equals(id))).write(
      const AppAnalyticsCompanion(synced: Value(true)),
    );
  }

  Future<List<User>> getAllUsers() =>
      (select(users)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  // Tracking
  Future<int> insertTrackingEvent(TrackingEventsCompanion entry) =>
      into(trackingEvents).insert(entry);

  Stream<List<TrackingEvent>> watchTrackingEvents({
    required String entityType,
    required int entityId,
  }) {
    return (select(trackingEvents)
          ..where((t) => t.entityType.equals(entityType) & t.entityId.equals(entityId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<List<AppAnalytic>> getAllAnalytics() =>
      (select(appAnalytics)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  // Project time tracking
  Future<void> stopActiveTimeEntryForUser(int ownerUserId) async {
    final active = await getActiveTimeEntryForUser(ownerUserId);
    if (active != null) {
      await stopTimeEntry(active.id);
    }
  }

  @Deprecated('Use getActiveTimeEntryForUser(ownerUserId) instead')
  Future<ProjectTimeEntry?> getActiveTimeEntry() =>
      (select(projectTimeEntries)..where((t) => t.endedAt.isNull())).getSingleOrNull();

  Future<int> startTimeEntry(int ownerUserId, int projectId) async {
    final active = await getActiveTimeEntryForUser(ownerUserId);
    if (active != null) {
      await stopTimeEntry(active.id);
    }
    return into(projectTimeEntries).insert(
      ProjectTimeEntriesCompanion.insert(
        ownerUserId: ownerUserId,
        projectId: projectId,
        startedAt: DateTime.now(),
      ),
    );
  }

  Future<void> stopTimeEntry(int entryId) async {
    final entry = await (select(projectTimeEntries)..where((t) => t.id.equals(entryId))).getSingleOrNull();
    if (entry == null || entry.endedAt != null) return;
    final ended = DateTime.now();
    final duration = ended.difference(entry.startedAt).inSeconds;
    await (update(projectTimeEntries)..where((t) => t.id.equals(entryId))).write(
      ProjectTimeEntriesCompanion(
        endedAt: Value(ended),
        durationSeconds: Value(duration),
      ),
    );
  }

  Future<void> stopActiveTimeEntry() async {
    // Legacy global stop, only closes entries without endedAt (prefer user-scoped API).
    final active = await getActiveTimeEntry();
    if (active != null) {
      await stopTimeEntry(active.id);
    }
  }

  Future<int> totalSecondsForProject(int projectId) async {
    final entries = await (select(projectTimeEntries)..where((t) => t.projectId.equals(projectId))).get();
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

  Stream<List<ProjectTimeEntry>> watchProjectTimeEntries(int projectId) {
    return (select(projectTimeEntries)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .watch();
  }

  Stream<Map<int, int>> watchAllProjectTrackedSeconds() {
    return select(projectTimeEntries).watch().map((entries) {
      final totals = <int, int>{};
      for (final e in entries) {
        if (e.endedAt != null) {
          totals[e.projectId] = (totals[e.projectId] ?? 0) + e.durationSeconds;
        }
      }
      return totals;
    });
  }

  // File attachments
  Future<List<FileAttachment>> getAttachmentsForEntity({
    required int ownerUserId,
    required String entityType,
    required int entityId,
  }) {
    return (select(fileAttachments)
          ..where(
            (t) =>
                t.ownerUserId.equals(ownerUserId) &
                t.entityType.equals(entityType) &
                t.entityId.equals(entityId),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<List<FileAttachment>> watchAllAttachmentsForUser(int ownerUserId) {
    return (select(fileAttachments)
          ..where((t) => t.ownerUserId.equals(ownerUserId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<int> insertAttachment(FileAttachmentsCompanion entry) => into(fileAttachments).insert(entry);

  Future<int> deleteAttachment(int id) =>
      (delete(fileAttachments)..where((t) => t.id.equals(id))).go();

  // Calendar reminders
  Stream<List<CalendarReminder>> watchRemindersForUser(int ownerUserId) {
    return (select(calendarReminders)
          ..where((t) => t.ownerUserId.equals(ownerUserId) & t.completed.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(calendarReminders.scheduledAt)]))
        .watch();
  }

  Future<int> insertReminder(CalendarRemindersCompanion entry) =>
      into(calendarReminders).insert(entry);

  Future<bool> completeReminder(int id) async {
    final row = await (select(calendarReminders)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return false;
    return update(calendarReminders).replace(row.copyWith(completed: true));
  }

  Future<List<TrackingEvent>> watchAllTrackingForUser(int ownerUserId) {
    return (select(trackingEvents)
          ..where((t) => t.ownerUserId.equals(ownerUserId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  // ── Sync outbox / conflicts (schema v18) ─────────────────────────────

  Future<int> insertSyncOutbox(SyncOutboxEntriesCompanion entry) =>
      into(syncOutboxEntries).insert(entry);

  Future<List<SyncOutboxEntry>> listActiveOutbox({int? ownerUserId}) {
    final q = select(syncOutboxEntries)
      ..where(
        (t) =>
            t.status.isNotIn(const ['completed']) &
            (ownerUserId == null
                ? const Constant(true)
                : t.ownerUserId.equals(ownerUserId) | t.ownerUserId.isNull()),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return q.get();
  }

  Future<List<SyncOutboxEntry>> listDueOutbox({int? ownerUserId}) async {
    final now = DateTime.now();
    final rows = await listActiveOutbox(ownerUserId: ownerUserId);
    return rows
        .where(
          (r) =>
              r.status == 'pending' ||
              r.status == 'retrying' ||
              (r.status == 'processing' &&
                  r.updatedAt.isBefore(now.subtract(const Duration(minutes: 5)))),
        )
        .where((r) => r.nextAttemptAt == null || !r.nextAttemptAt!.isAfter(now))
        .toList();
  }

  Future<bool> updateSyncOutbox(SyncOutboxEntry entry) =>
      update(syncOutboxEntries).replace(entry);

  Future<int> clearCompletedOutboxOlderThan(Duration age) {
    final cutoff = DateTime.now().subtract(age);
    return (delete(syncOutboxEntries)
          ..where(
            (t) =>
                t.status.equals('completed') & t.completedAt.isSmallerThanValue(cutoff),
          ))
        .go();
  }

  Future<int> deleteOutboxForUser(int ownerUserId) =>
      (delete(syncOutboxEntries)..where((t) => t.ownerUserId.equals(ownerUserId))).go();

  Future<int> countPendingOutbox({int? ownerUserId}) async {
    final rows = await (select(syncOutboxEntries)
          ..where(
            (t) =>
                t.status.isIn(const ['pending', 'processing', 'retrying', 'conflicted']) &
                (ownerUserId == null
                    ? const Constant(true)
                    : t.ownerUserId.equals(ownerUserId) | t.ownerUserId.isNull()),
          ))
        .get();
    return rows.length;
  }

  Future<DateTime?> lastSuccessfulSyncAt({int? ownerUserId}) async {
    final rows = await (select(syncOutboxEntries)
          ..where(
            (t) =>
                t.status.equals('completed') &
                (ownerUserId == null
                    ? const Constant(true)
                    : t.ownerUserId.equals(ownerUserId) | t.ownerUserId.isNull()),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.completedAt)])
          ..limit(1))
        .get();
    if (rows.isEmpty) return null;
    return rows.first.completedAt ?? rows.first.updatedAt;
  }

  Future<int> insertSyncConflict(SyncConflictEntriesCompanion entry) =>
      into(syncConflictEntries).insert(entry);

  Future<List<SyncConflictEntry>> listSyncConflicts({int? ownerUserId}) {
    final q = select(syncConflictEntries)
      ..where(
        (t) => ownerUserId == null
            ? const Constant(true)
            : t.ownerUserId.equals(ownerUserId) | t.ownerUserId.isNull(),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return q.get();
  }

  Future<int> deleteSyncConflict({
    required String entityType,
    required int localId,
    int? ownerUserId,
  }) {
    return (delete(syncConflictEntries)
          ..where(
            (t) =>
                t.entityType.equals(entityType) &
                t.localId.equals(localId) &
                (ownerUserId == null
                    ? const Constant(true)
                    : t.ownerUserId.equals(ownerUserId) | t.ownerUserId.isNull()),
          ))
        .go();
  }

  Future<int> deleteAllSyncConflicts({int? ownerUserId}) {
    if (ownerUserId == null) {
      return delete(syncConflictEntries).go();
    }
    return (delete(syncConflictEntries)
          ..where((t) => t.ownerUserId.equals(ownerUserId) | t.ownerUserId.isNull()))
        .go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'clivora.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
