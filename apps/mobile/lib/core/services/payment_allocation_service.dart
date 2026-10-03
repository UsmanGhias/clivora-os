import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import '../auth/auth_service.dart';

final paymentAllocationServiceProvider =
    Provider<PaymentAllocationService>((ref) => PaymentAllocationService(ref));

class PaymentAllocationService {
  PaymentAllocationService(this.ref);
  final Ref ref;

  Future<void> recordPayment({
    required int invoiceId,
    required double amount,
    String method = 'other',
    String reference = '',
    String notes = '',
  }) async {
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) throw StateError('Sign in required');
    if (amount <= 0) throw StateError('Amount must be positive');

    final db = ref.read(databaseProvider);
    final invoice = await db.getInvoiceForUser(ownerId, invoiceId);
    if (invoice == null) throw StateError('Invoice not found');

    await db.insertInvoicePayment(
      InvoicePaymentsCompanion.insert(
        ownerUserId: ownerId,
        invoiceId: invoiceId,
        customerId: Value(invoice.customerId),
        amount: amount,
        currency: Value(invoice.currency),
        method: Value(method),
        reference: Value(reference),
        notes: Value(notes),
      ),
    );

    final paid = invoice.amountPaid + amount;
    final status = paid + 0.001 >= invoice.total ? 'paid' : 'sent';
    await db.updateInvoice(
      invoice.copyWith(
        amountPaid: paid,
        status: status,
        updatedAt: DateTime.now(),
      ),
    );

    ref.invalidate(invoicePaymentsProvider);
    ref.invalidate(invoicesProvider);
    ref.invalidate(dashboardStatsProvider);
  }

  Future<void> applyCredit({
    required int creditId,
    required int invoiceId,
    required double amount,
  }) async {
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) throw StateError('Sign in required');
    final db = ref.read(databaseProvider);
    final credit = await db.getCreditForUser(ownerId, creditId);
    final invoice = await db.getInvoiceForUser(ownerId, invoiceId);
    if (credit == null || invoice == null) throw StateError('Not found');
    if (credit.customerId != invoice.customerId) {
      throw StateError('Credit belongs to a different client');
    }
    final apply = amount.clamp(0, credit.balance).toDouble();
    if (apply <= 0) return;

    await recordPayment(
      invoiceId: invoiceId,
      amount: apply,
      method: 'credit',
      reference: credit.creditNumber,
      notes: 'Applied credit ${credit.creditNumber}',
    );

    final balance = credit.balance - apply;
    await db.updateCredit(
      credit.copyWith(
        balance: balance,
        status: balance <= 0.001 ? 'applied' : 'open',
        updatedAt: DateTime.now(),
      ),
    );
    ref.invalidate(creditsProvider);
  }
}
