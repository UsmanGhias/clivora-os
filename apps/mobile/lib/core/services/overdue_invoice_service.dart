import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cloud/cloud_notification_repository.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import '../auth/auth_service.dart';
import 'automation_service.dart';
import 'local_notification_service.dart';
import 'notification_prefs_service.dart';

final overdueInvoiceServiceProvider = Provider<OverdueInvoiceService>((ref) {
  return OverdueInvoiceService(ref);
});

/// Promotes sent invoices past dueDate → overdue and fires day 0/3/7 reminders.
class OverdueInvoiceService {
  OverdueInvoiceService(this.ref);
  final Ref ref;

  static const _remindKeyPrefix = 'overdue_remind_';

  Future<int> scanAndPromote() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return 0;
    final db = ref.read(databaseProvider);
    final invoices = await db.watchInvoicesForUser(user.id).first;
    final now = DateTime.now();
    var changed = 0;

    for (final inv in invoices) {
      if (inv.status != 'sent') continue;
      final due = inv.dueDate;
      if (due == null) continue;
      if (!due.isBefore(now)) continue;

      final previous = inv.status;
      await db.updateInvoice(inv.copyWith(status: 'overdue', updatedAt: now));
      changed++;
      try {
        await ref.read(automationServiceProvider).onInvoiceSaved(
              inv.copyWith(status: 'overdue'),
              previousStatus: previous,
            );
      } catch (e) {
        debugPrint('Overdue automation failed: $e');
      }
      await _maybeRemind(inv.id, inv.invoiceNumber, inv.customerId, 0);
    }

    for (final inv in invoices.where((i) => i.status == 'overdue')) {
      final due = inv.dueDate;
      if (due == null) continue;
      final days = now.difference(due).inDays;
      if (days >= 7) {
        await _maybeRemind(inv.id, inv.invoiceNumber, inv.customerId, 7);
      } else if (days >= 3) {
        await _maybeRemind(inv.id, inv.invoiceNumber, inv.customerId, 3);
      }
    }

    if (changed > 0) {
      ref.invalidate(invoicesProvider);
      ref.invalidate(dashboardStatsProvider);
    }
    return changed;
  }

  Future<void> _maybeRemind(int invoiceId, String number, int customerId, int day) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_remindKeyPrefix${invoiceId}_d$day';
    if (prefs.getBool(key) == true) return;
    await prefs.setBool(key, true);

    if (!await ref.read(notificationPrefsServiceProvider).billingEnabled()) return;

    await ref.read(localNotificationServiceProvider).show(
          title: day == 0 ? 'Invoice overdue' : 'Overdue reminder (day $day)',
          body: 'Invoice $number is overdue. Send a follow-up.',
          payload: 'invoice:$invoiceId',
        );

    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) return;
      final customer = await ref.read(databaseProvider).getCustomerForUser(user.id, customerId);
      if (customer == null) return;
      final email = _firstEmail(customer.emails);
      if (email.isEmpty) return;
      await ref.read(cloudNotificationRepositoryProvider).send(
            toEmail: email,
            title: 'Invoice $number overdue',
            body: day == 0
                ? 'Your invoice is now overdue. Please review payment.'
                : 'Friendly reminder: invoice $number is still unpaid (day $day).',
            kind: 'invoice',
          );
    } catch (e) {
      debugPrint('Overdue client notify failed: $e');
    }
  }

  String _firstEmail(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List && decoded.isNotEmpty) {
        return decoded.first.toString().trim().toLowerCase();
      }
    } catch (_) {}
    return raw.trim().toLowerCase();
  }
}
