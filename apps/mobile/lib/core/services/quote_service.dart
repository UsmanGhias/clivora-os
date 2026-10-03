import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import '../auth/auth_service.dart';

final quoteServiceProvider = Provider<QuoteService>((ref) => QuoteService(ref));

class QuoteService {
  QuoteService(this.ref);
  final Ref ref;

  Future<int> convertToInvoice(int quoteId) async {
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) throw StateError('Sign in required');
    final db = ref.read(databaseProvider);
    final quote = await db.getQuoteForUser(ownerId, quoteId);
    if (quote == null) throw StateError('Quote not found');
    if (quote.convertedInvoiceId != null) {
      return quote.convertedInvoiceId!;
    }

    final number = 'INV-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}';
    final invoiceId = await db.insertInvoice(
      InvoicesCompanion.insert(
        ownerUserId: ownerId,
        invoiceNumber: number,
        customerId: quote.customerId,
        projectId: Value(quote.projectId),
        status: const Value('draft'),
        subtotal: Value(quote.subtotal),
        taxRate: Value(quote.taxRate),
        discount: Value(quote.discount),
        total: Value(quote.total),
        currency: Value(quote.currency),
        lineItems: Value(quote.lineItems),
        quoteId: Value(quote.id),
        dueDate: Value(DateTime.now().add(const Duration(days: 14))),
      ),
    );

    await db.updateQuote(
      quote.copyWith(
        status: 'accepted',
        convertedInvoiceId: Value(invoiceId),
        updatedAt: DateTime.now(),
      ),
    );

    ref.invalidate(quotesProvider);
    ref.invalidate(invoicesProvider);
    ref.invalidate(dashboardStatsProvider);
    return invoiceId;
  }
}
