import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import 'invoice_pdf_service.dart';

Future<void> shareInvoicePdf(
  WidgetRef ref,
  BuildContext context,
  int invoiceId,
) async {
  final db = ref.read(databaseProvider);
  final userId = ref.read(authStateProvider).valueOrNull?.id;
  if (userId == null) return;
  final invoice = await db.getInvoiceForUser(userId, invoiceId);
  if (invoice == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice not found')),
      );
    }
    return;
  }

  final customer = await db.getCustomerForUser(userId, invoice.customerId);
  if (customer == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer not found for this invoice')),
      );
    }
    return;
  }

  BusinessProfile business;
  InvoiceBranding branding;
  try {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) throw StateError('Not signed in');
    final db = ref.read(databaseProvider);
    business = await db.getOrCreateBusinessProfile(userId);
    branding = await db.getOrCreateInvoiceBranding(userId);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load invoice settings: $e')),
      );
    }
    return;
  }

  Project? project;
  if (invoice.projectId != null) {
    project = await db.getProjectForUser(userId, invoice.projectId!);
  }

  try {
    await InvoicePdfService.sharePdf(
      invoice: invoice,
      customer: customer,
      business: business,
      branding: branding,
      project: project,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share PDF: $e')),
      );
    }
  }
}
