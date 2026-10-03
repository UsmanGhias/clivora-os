import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/cloud/cloud_invoice_repository.dart';
import '../../core/constants/plan_limits.dart';
import '../../core/utils/plan_limit_dialog.dart';
import 'package:go_router/go_router.dart';
import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/models/invoice_line_item.dart';
import '../../data/providers/app_providers.dart';
import 'client_pdf_quota_service.dart';
import 'invoice_pdf_service.dart';

/// Preview a shared invoice with the freelancer's branding (client portal).
Future<void> previewClientInvoice(
  WidgetRef ref,
  BuildContext context,
  Invoice invoice,
) async {
  await _previewInvoice(ref, context, invoice);
}

/// Preview from cloud share when no local invoice copy exists on the client device.
Future<void> previewClientInvoiceFromShare(
  WidgetRef ref,
  BuildContext context,
  CloudInvoiceShare share,
) async {
  final client = ref.read(authStateProvider).valueOrNull;
  if (client == null) return;

  final db = ref.read(databaseProvider);
  User? freelancer;
  if (share.localProjectId != null) {
    freelancer = await db.getFreelancerUserForClientProject(client.id, share.localProjectId!);
  }
  if (freelancer == null) {
    final links = await db.getFreelancerLinksForClient(client.id);
    if (links.isNotEmpty) {
      freelancer = await db.getUser(links.first.freelancerUserId);
    }
  }
  if (freelancer == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load invoice details')),
      );
    }
    return;
  }

  final customers = await db.watchCustomersForUser(freelancer.id).first;
  Customer? customer;
  for (final c in customers) {
    if (c.emails.toLowerCase().contains(share.clientEmail.toLowerCase())) {
      customer = c;
      break;
    }
  }
  customer ??= customers.isNotEmpty ? customers.first : null;
  if (customer == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer record not found for this invoice')),
      );
    }
    return;
  }

  final synthetic = Invoice(
    id: share.localInvoiceId,
    ownerUserId: freelancer.id,
    invoiceNumber: share.invoiceNumber,
    customerId: customer.id,
    projectId: share.localProjectId,
    status: share.status,
    subtotal: share.total,
    taxRate: 0,
    discount: 0,
    total: share.total,
    amountPaid: share.status == 'paid' ? share.total : 0,
    currency: share.currency,
    lineItems: encodeLineItems([
      InvoiceLineItem(description: 'Invoice ${share.invoiceNumber}', quantity: 1, unitPrice: share.total),
    ]),
    issueDate: share.updatedAt ?? DateTime.now(),
    dueDate: share.dueDate,
    createdAt: share.updatedAt ?? DateTime.now(),
    updatedAt: share.updatedAt ?? DateTime.now(),
  );

  if (!context.mounted) return;
  await _previewInvoice(ref, context, synthetic, freelancerId: freelancer.id);
}

Future<void> _previewInvoice(
  WidgetRef ref,
  BuildContext context,
  Invoice invoice, {
  int? freelancerId,
}) async {
  if (!await ref.read(planLimitServiceProvider).canDownloadClientInvoicePdf()) {
    if (context.mounted) {
      final upgrade = await showPlanLimitDialog(
        context,
        resource: 'invoice PDF downloads this month',
        max: PlanLimits.freeMaxClientInvoiceDownloads,
      );
      if (upgrade && context.mounted) context.push('/upgrade');
    }
    return;
  }

  final client = ref.read(authStateProvider).valueOrNull;
  if (client == null) return;

  final db = ref.read(databaseProvider);
  final freelancer = freelancerId != null
      ? await db.getUser(freelancerId)
      : await db.getFreelancerUserForClientInvoice(client.id, invoice);
  if (freelancer == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load invoice details')),
      );
    }
    return;
  }

  final customer = await db.getCustomerForUser(freelancer.id, invoice.customerId);
  if (customer == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer record not found')),
      );
    }
    return;
  }

  BusinessProfile business;
  InvoiceBranding branding;
  try {
    business = await db.getOrCreateBusinessProfile(freelancer.id);
    branding = await db.getOrCreateInvoiceBranding(freelancer.id);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load branding: $e')),
      );
    }
    return;
  }

  Project? project;
  if (invoice.projectId != null) {
    project = await db.getProjectForUser(freelancer.id, invoice.projectId!);
  }

  try {
    await ref.read(clientPdfQuotaServiceProvider).recordDownload();
    await InvoicePdfService.previewPdf(
      invoice: invoice,
      customer: customer,
      business: business,
      branding: branding,
      project: project,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open invoice: $e')),
      );
    }
  }
}
