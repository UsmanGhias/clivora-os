import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/plan_limits.dart';
import '../../core/services/sync_outbox_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/crm_refresh.dart';
import '../../core/utils/navigation_helper.dart';
import '../../data/models/invoice_line_item.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_bottom_sheet.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/contact_action_chips.dart';
import '../../shared/widgets/empty_state.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchController = TextEditingController();
  String? _search;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showEntityConflictDialog(context, ref);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onAddCustomer() async {
    await tryOpenWithPlanCheck(
      context,
      ref: ref,
      canAdd: () => ref.read(planLimitServiceProvider).canAddCustomer(),
      path: '/customers/new',
      resource: 'clients',
      max: PlanLimits.freeMaxClients,
    );
  }

  Future<void> _deleteCustomer(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete customer?'),
        content: Text('Remove $name? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(syncOutboxServiceProvider).enqueue(
            SyncOutboxItem(
              kind: 'crm_customer_delete',
              payload: {'localId': id},
              isTombstone: true,
            ),
          );
      await ref.read(databaseProvider).deleteCustomer(id);
      invalidateCrmData(ref, customers: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider(_search));
    final customerCountAsync = ref.watch(customerCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClivoraScaffold(
      title: 'Customers',
      showMessagesButton: true,
      action: ClivoraIconButton(icon: Icons.add, onPressed: _onAddCustomer),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? ClivoraColors.darkBorder : ClivoraColors.chipBackground,
              borderRadius: BorderRadius.circular(28),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _search = v.isEmpty ? null : v),
              decoration: const InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: Icon(Icons.search, color: ClivoraColors.textSecondary),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          customerCountAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (count) => PlanLimitBanner(
              current: count,
              max: PlanLimits.freeMaxClients,
              resource: 'clients',
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (customers) {
                if (customers.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline,
                    message: _search != null ? 'No customers found' : 'No customers yet',
                    actionLabel: _search == null ? 'Add client' : null,
                    onAction: _search == null ? _onAddCustomer : null,
                  );
                }
                return ListView.separated(
                  itemCount: customers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final c = customers[index];
                    final emails = parseStringList(c.emails);
                    final phones = parseStringList(c.phones);
                    final initial = c.contactPerson.isNotEmpty
                        ? c.contactPerson[0].toUpperCase()
                        : (c.company.isNotEmpty ? c.company[0].toUpperCase() : '?');
                    final subtitle = emails.isNotEmpty
                        ? emails.first
                        : (c.company.isNotEmpty ? c.company : 'No contact info');

                    return Material(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => openFormRoute(context, '/customers/${c.id}/edit'),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark ? ClivoraColors.darkBorder : ClivoraColors.borderLight,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: ClivoraColors.primaryLight,
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        color: ClivoraColors.primaryDark,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.contactPerson,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            color: ClivoraColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          subtitle,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: ClivoraColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  _SquareIconButton(
                                    icon: Icons.edit_outlined,
                                    color: ClivoraColors.textSecondary,
                                    bg: isDark ? ClivoraColors.darkBorder : ClivoraColors.chipBackground,
                                    onTap: () => openFormRoute(context, '/customers/${c.id}/edit'),
                                  ),
                                  const SizedBox(width: 8),
                                  _SquareIconButton(
                                    icon: Icons.delete_outline,
                                    color: ClivoraColors.errorRed,
                                    bg: ClivoraColors.iconRed,
                                    onTap: () => _deleteCustomer(c.id, c.contactPerson),
                                  ),
                                ],
                              ),
                              ContactActionChips(
                                phone: phones.isNotEmpty ? phones.first : '',
                                email: emails.isNotEmpty ? emails.first : '',
                                whatsapp: c.whatsapp,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
