import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/models/invoice_line_item.dart';
import '../../data/providers/app_providers.dart';
import '../auth/auth_service.dart';

final billableToInvoiceServiceProvider =
    Provider<BillableToInvoiceService>((ref) => BillableToInvoiceService(ref));

/// Convert completed tasks, tracked time, and billable expenses into a draft invoice.
class BillableToInvoiceService {
  BillableToInvoiceService(this.ref);
  final Ref ref;

  Future<int> createFromProject({
    required int projectId,
    required int customerId,
    double hourlyRate = 0,
  }) async {
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) throw StateError('Sign in required');
    final db = ref.read(databaseProvider);

    final tasks = await db.watchTasksForUser(ownerId).first;
    final projectTasks = tasks.where((t) => t.projectId == projectId && t.completed).toList();
    final timeEntries = await db.watchProjectTimeEntriesForUser(ownerId, projectId).first;
    final expenses = await db.billableExpensesForUser(ownerId, customerId: customerId);

    final lines = <InvoiceLineItem>[];
    for (final t in projectTasks) {
      lines.add(InvoiceLineItem(
        description: 'Task: ${t.title}',
        quantity: 1,
        unitPrice: hourlyRate > 0 ? hourlyRate : 0,
      ));
    }
    if (hourlyRate > 0) {
      final seconds = timeEntries.fold<int>(0, (s, e) => s + e.durationSeconds);
      final hours = seconds / 3600.0;
      if (hours > 0) {
        lines.add(InvoiceLineItem(
          description: 'Billable time (${hours.toStringAsFixed(2)}h)',
          quantity: double.parse(hours.toStringAsFixed(2)),
          unitPrice: hourlyRate,
        ));
      }
    }
    final projectExpenses = expenses.where((x) => x.projectId == null || x.projectId == projectId).toList();
    for (final e in projectExpenses) {
      lines.add(InvoiceLineItem(description: 'Expense: ${e.title}', quantity: 1, unitPrice: e.amount));
    }
    if (lines.isEmpty) {
      throw StateError('No billable tasks, time, or expenses found for this project');
    }

    final subtotal = lines.fold<double>(0, (s, l) => s + l.amount);
    final invoiceId = await db.insertInvoice(
      InvoicesCompanion.insert(
        ownerUserId: ownerId,
        invoiceNumber: 'INV-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}',
        customerId: customerId,
        projectId: Value(projectId),
        status: const Value('draft'),
        subtotal: Value(subtotal),
        total: Value(subtotal),
        lineItems: Value(encodeLineItems(lines)),
        dueDate: Value(DateTime.now().add(const Duration(days: 14))),
      ),
    );

    for (final e in projectExpenses) {
      await db.updateExpense(
        e.copyWith(isInvoiced: true, invoiceId: Value(invoiceId)),
      );
    }

    ref.invalidate(invoicesProvider);
    ref.invalidate(expensesProvider);
    ref.invalidate(dashboardStatsProvider);
    return invoiceId;
  }
}
