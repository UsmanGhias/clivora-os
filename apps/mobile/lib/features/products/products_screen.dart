import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/form_dialog_fields.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    return ClivoraScaffold(
      title: 'Products & Services',
      showBackButton: true,
      action: ClivoraIconButton(
        icon: Icons.add,
        onPressed: () => _edit(context, ref, null),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.inventory_2_outlined,
              message: 'Build your catalog of services and products for faster invoicing.',
              actionLabel: 'Add item',
              onAction: () => _edit(context, ref, null),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final p = items[i];
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
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${p.isService ? 'Service' : 'Product'}'
                    '${p.sku.isNotEmpty ? ' · ${p.sku}' : ''}'
                    '${p.description.isNotEmpty ? '\n${p.description}' : ''}',
                  ),
                  isThreeLine: p.description.isNotEmpty,
                  trailing: Text(
                    formatCurrency(p.unitPrice),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: ClivoraColors.primary),
                  ),
                  onTap: () => _edit(context, ref, p),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Product? existing) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final desc = TextEditingController(text: existing?.description ?? '');
    final sku = TextEditingController(text: existing?.sku ?? '');
    final price = TextEditingController(text: existing != null ? existing.unitPrice.toString() : '');
    final tax = TextEditingController(text: existing != null ? existing.taxRate.toString() : '0');
    var isService = existing?.isService ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'New catalog item' : 'Edit item'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: spacedDialogFields([
                  TextField(controller: name, decoration: clivoraDialogFieldDecoration(ctx, 'Name')),
                  TextField(
                    controller: desc,
                    decoration: clivoraDialogFieldDecoration(ctx, 'Description'),
                    maxLines: 2,
                  ),
                  TextField(controller: sku, decoration: clivoraDialogFieldDecoration(ctx, 'SKU (optional)')),
                  TextField(
                    controller: price,
                    decoration: clivoraDialogFieldDecoration(ctx, 'Unit price'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: tax,
                    decoration: clivoraDialogFieldDecoration(ctx, 'Tax %'),
                    keyboardType: TextInputType.number,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Service (not physical product)'),
                    value: isService,
                    onChanged: (v) => setLocal(() => isService = v),
                  ),
                ]),
              ),
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  final ownerId = ref.read(authStateProvider).valueOrNull?.id;
                  if (ownerId == null) return;
                  await ref.read(databaseProvider).deleteProductForUser(ownerId, existing.id);
                  ref.invalidate(productsProvider);
                  if (ctx.mounted) Navigator.pop(ctx, false);
                },
                child: const Text('Delete'),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return;
    final db = ref.read(databaseProvider);
    final unit = double.tryParse(price.text.trim()) ?? 0;
    final taxRate = double.tryParse(tax.text.trim()) ?? 0;
    if (existing == null) {
      await db.insertProduct(
        ProductsCompanion.insert(
          ownerUserId: ownerId,
          name: name.text.trim(),
          description: Value(desc.text.trim()),
          sku: Value(sku.text.trim()),
          unitPrice: Value(unit),
          taxRate: Value(taxRate),
          isService: Value(isService),
        ),
      );
    } else {
      await db.updateProduct(
        existing.copyWith(
          name: name.text.trim(),
          description: desc.text.trim(),
          sku: sku.text.trim(),
          unitPrice: unit,
          taxRate: taxRate,
          isService: isService,
          updatedAt: DateTime.now(),
        ),
      );
    }
    ref.invalidate(productsProvider);
  }
}
