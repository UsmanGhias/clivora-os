import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/models/invoice_line_item.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/empty_state.dart';

class PurchaseOrdersScreen extends ConsumerWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posAsync = ref.watch(purchaseOrdersProvider);
    final vendorsAsync = ref.watch(vendorsProvider);

    return ClivoraScaffold(
      title: 'Purchase orders',
      showBackButton: true,
      action: IconButton(icon: const Icon(Icons.add), onPressed: () => _create(context, ref)),
      body: posAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_bag_outlined,
              message: 'Create lightweight purchase orders for vendors.',
              actionLabel: 'New PO',
              onAction: () => _create(context, ref),
            );
          }
          final vendors = {for (final v in vendorsAsync.valueOrNull ?? []) v.id: v};
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final po = items[i];
              final vendor = vendors[po.vendorId];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? ClivoraColors.darkBorder
                        : ClivoraColors.borderLight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(po.poNumber, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${vendor?.name ?? 'Vendor'} · ${po.status}'),
                    Text(formatCurrency(po.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (po.status == 'draft')
                      TextButton(
                        onPressed: () async {
                          await ref.read(databaseProvider).updatePurchaseOrder(
                                po.copyWith(status: 'sent', updatedAt: DateTime.now()),
                              );
                          ref.invalidate(purchaseOrdersProvider);
                        },
                        child: const Text('Mark sent'),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final vendors = await ref.read(vendorsProvider.future);
    if (vendors.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a vendor first')),
        );
      }
      return;
    }
    var vendorId = vendors.first.id;
    final desc = TextEditingController(text: 'Supplies');
    final amount = TextEditingController(text: '0');
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New purchase order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: vendorId,
                decoration: const InputDecoration(labelText: 'Vendor'),
                items: vendors.map((v) => DropdownMenuItem(value: v.id, child: Text(v.name))).toList(),
                onChanged: (v) => setLocal(() => vendorId = v ?? vendorId),
              ),
              TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
              TextField(
                controller: amount,
                decoration: const InputDecoration(labelText: 'Total'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return;
    final total = double.tryParse(amount.text.trim()) ?? 0;
    final items = [InvoiceLineItem(description: desc.text.trim(), quantity: 1, unitPrice: total)];
    await ref.read(databaseProvider).insertPurchaseOrder(
          PurchaseOrdersCompanion.insert(
            ownerUserId: ownerId,
            poNumber: 'PO-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}',
            vendorId: vendorId,
            total: Value(total),
            lineItems: Value(encodeLineItems(items)),
          ),
        );
    ref.invalidate(purchaseOrdersProvider);
  }
}
