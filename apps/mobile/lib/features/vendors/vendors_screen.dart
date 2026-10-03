import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/empty_state.dart';

class VendorsScreen extends ConsumerWidget {
  const VendorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorsAsync = ref.watch(vendorsProvider);
    return ClivoraScaffold(
      title: 'Vendors',
      showBackButton: true,
      action: IconButton(icon: const Icon(Icons.add), onPressed: () => _edit(context, ref, null)),
      body: vendorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.storefront_outlined,
              message: 'Track suppliers for expenses and purchase orders.',
              actionLabel: 'Add vendor',
              onAction: () => _edit(context, ref, null),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final v = items[i];
              return Container(
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
                  title: Text(v.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([v.email, v.phone].where((e) => e.isNotEmpty).join(' · ')),
                  onTap: () => _edit(context, ref, v),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Vendor? existing) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final email = TextEditingController(text: existing?.email ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'New vendor' : 'Edit vendor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return;
    final db = ref.read(databaseProvider);
    if (existing == null) {
      await db.insertVendor(
        VendorsCompanion.insert(
          ownerUserId: ownerId,
          name: name.text.trim(),
          email: Value(email.text.trim()),
          phone: Value(phone.text.trim()),
          notes: Value(notes.text.trim()),
        ),
      );
    } else {
      await db.updateVendor(
        existing.copyWith(
          name: name.text.trim(),
          email: email.text.trim(),
          phone: phone.text.trim(),
          notes: notes.text.trim(),
        ),
      );
    }
    ref.invalidate(vendorsProvider);
  }
}
