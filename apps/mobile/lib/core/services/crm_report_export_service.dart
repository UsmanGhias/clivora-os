import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/providers/app_providers.dart';
import '../auth/auth_service.dart';
import '../utils/currency_formatter.dart';

final crmReportExportServiceProvider =
    Provider<CrmReportExportService>((ref) => CrmReportExportService(ref));

/// Exports CRM financial reports (P&L, aging, tax, expenses) as CSV.
class CrmReportExportService {
  CrmReportExportService(this.ref);
  final Ref ref;

  Future<void> exportAndShare() async {
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) throw StateError('Sign in required');

    final data = await ref.read(reportsProvider.future);
    final expenses = await ref.read(expensesProvider(null).future);
    final invoices = await ref.read(invoicesProvider(null).future);

    final byCategory = <String, double>{};
    final byVendor = <String, double>{};
    for (final e in expenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
      final vendorKey = e.vendor.isNotEmpty ? e.vendor : 'Unassigned';
      byVendor[vendorKey] = (byVendor[vendorKey] ?? 0) + e.amount;
    }

    final buf = StringBuffer();
    buf.writeln('CLIVORA Financial Report');
    buf.writeln('Generated,${DateTime.now().toIso8601String()}');
    buf.writeln();
    buf.writeln('P&L Summary');
    buf.writeln('Metric,Amount');
    buf.writeln('Revenue (paid),${data.revenue}');
    buf.writeln('Outstanding,${data.outstanding}');
    buf.writeln('Total expenses,${data.totalExpenses}');
    buf.writeln('Net profit,${data.profit}');
    buf.writeln('Tax on paid invoices,${data.taxCollected}');
    buf.writeln('Monthly expenses,${data.monthlyExpenses}');
    buf.writeln('Monthly profit,${data.monthlyProfit}');
    buf.writeln();
    buf.writeln('Invoice Aging');
    buf.writeln('Bucket,Amount');
    buf.writeln('Current,${data.agingCurrent}');
    buf.writeln('1-30,${data.aging30}');
    buf.writeln('31-60,${data.aging60}');
    buf.writeln('60+,${data.aging90}');
    buf.writeln();
    buf.writeln('Expenses by Category');
    buf.writeln('Category,Amount');
    for (final e in byCategory.entries) {
      buf.writeln('${_csv(e.key)},${e.value}');
    }
    buf.writeln();
    buf.writeln('Expenses by Vendor');
    buf.writeln('Vendor,Amount');
    for (final e in byVendor.entries) {
      buf.writeln('${_csv(e.key)},${e.value}');
    }
    buf.writeln();
    buf.writeln('Invoices');
    buf.writeln('Number,Status,Total,Paid,Balance,Currency');
    for (final inv in invoices) {
      final bal = (inv.total - inv.amountPaid).clamp(0, double.infinity);
      buf.writeln(
        '${_csv(inv.invoiceNumber)},${inv.status},${inv.total},${inv.amountPaid},$bal,${inv.currency}',
      );
    }

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/clivora-report-${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(buf.toString(), flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv', name: 'clivora-report.csv')],
        subject: 'CLIVORA financial report',
        text:
            'P&L ${formatCurrency(data.profit)} · Outstanding ${formatCurrency(data.outstanding)}',
      ),
    );
  }

  String _csv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
