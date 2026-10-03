import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import '../auth/auth_service.dart';

final recurringInvoiceServiceProvider = Provider<RecurringInvoiceService>((ref) {
  return RecurringInvoiceService(ref);
});

class RecurringInvoiceService {
  RecurringInvoiceService(this.ref);
  final Ref ref;

  DateTime nextRunAfter(DateTime from, String frequency) {
    switch (frequency) {
      case 'weekly':
        return from.add(const Duration(days: 7));
      case 'biweekly':
        return from.add(const Duration(days: 14));
      case 'quarterly':
        return DateTime(from.year, from.month + 3, from.day);
      case 'yearly':
        return DateTime(from.year + 1, from.month, from.day);
      case 'monthly':
      default:
        return DateTime(from.year, from.month + 1, from.day);
    }
  }

  /// Generate due recurring invoices for the signed-in user. Returns count created.
  Future<int> processDue() async {
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return 0;
    final db = ref.read(databaseProvider);
    final due = await db.dueRecurringInvoicesForUser(ownerId, DateTime.now());
    var created = 0;
    for (final tmpl in due) {
      final number = 'INV-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}-$created';
      final dueDate = DateTime.now().add(Duration(days: tmpl.dueDays));
      await db.insertInvoice(
        InvoicesCompanion.insert(
          ownerUserId: ownerId,
          invoiceNumber: number,
          customerId: tmpl.customerId,
          projectId: Value(tmpl.projectId),
          status: const Value('sent'),
          subtotal: Value(tmpl.subtotal),
          taxRate: Value(tmpl.taxRate),
          discount: Value(tmpl.discount),
          total: Value(tmpl.total),
          currency: Value(tmpl.currency),
          lineItems: Value(tmpl.lineItems),
          recurringInvoiceId: Value(tmpl.id),
          dueDate: Value(dueDate),
        ),
      );
      final next = nextRunAfter(tmpl.nextRunAt, tmpl.frequency);
      await db.updateRecurringInvoice(
        tmpl.copyWith(
          lastRunAt: Value(DateTime.now()),
          nextRunAt: next,
          updatedAt: DateTime.now(),
        ),
      );
      created++;
    }
    if (created > 0) {
      ref.invalidate(invoicesProvider);
      ref.invalidate(recurringInvoicesProvider);
      ref.invalidate(dashboardStatsProvider);
    }
    return created;
  }
}
