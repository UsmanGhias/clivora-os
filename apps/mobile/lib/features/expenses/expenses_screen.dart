import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_service.dart';
import '../../core/services/billable_to_invoice_service.dart';
import '../../core/services/email_verification_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/database.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/stat_summary_card.dart';

const expenseCategories = [
  'all',
  'software',
  'hardware',
  'internet',
  'office',
  'travel',
  'food',
  'marketing',
  'equipment',
  'taxes',
  'other',
];

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _category = 'all';

  Future<void> _openNewExpense() async {
    if (!await requireEmailVerified(context, ref, actionLabel: 'add expenses')) return;
    if (!mounted) return;
    context.push('/expenses/new');
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(
      expensesProvider(_category == 'all' ? null : _category),
    );
    final statsAsync = ref.watch(expenseStatsProvider);

    return ClivoraScaffold(
      title: 'Expenses',
      showBackButton: true,
      action: ClivoraIconButton(
        icon: Icons.add,
        onPressed: _openNewExpense,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          statsAsync.when(
            loading: () => const SizedBox(height: 80),
            error: (_, _) => const SizedBox.shrink(),
            data: (stats) => StatSummaryCard(
              items: [
                StatItem(label: 'Total', value: formatCurrency(stats.total)),
                StatItem(label: 'This Month', value: formatCurrency(stats.monthly), valueColor: ClivoraColors.warningOrange),
                StatItem(label: 'Count', value: '${stats.count}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: expenseCategories.map((c) {
                final selected = _category == c;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(c == 'all' ? 'All' : c[0].toUpperCase() + c.substring(1)),
                    selected: selected,
                    onSelected: (_) => setState(() => _category = c),
                    selectedColor: ClivoraColors.primaryPurple.withValues(alpha: 0.15),
                    checkmarkColor: ClivoraColors.primaryPurple,
                    side: BorderSide(
                      color: selected ? ClivoraColors.primaryPurple : ClivoraColors.borderLight,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: expensesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (expenses) {
                if (expenses.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_outlined,
                    message: 'No expenses yet',
                    actionLabel: 'Add your first expense',
                    onAction: _openNewExpense,
                  );
                }
                return ListView.separated(
                  itemCount: expenses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return Dismissible(
                      key: ValueKey(expense.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete expense?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                ],
                              ),
                            ) ??
                            false;
                      },
                      onDismissed: (_) => ref.read(databaseProvider).deleteExpense(expense.id),
                      child: ListTile(
                        onTap: () => context.push('/expenses/${expense.id}/edit'),
                        tileColor: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        leading: const Icon(Icons.receipt, color: ClivoraColors.errorRed),
                        title: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${expense.category[0].toUpperCase()}${expense.category.substring(1)} · ${DateFormat('MMM d').format(expense.expenseDate)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (expense.isBillable && !expense.isInvoiced)
                              IconButton(
                                tooltip: 'Bill to invoice',
                                icon: const Icon(Icons.receipt_long_outlined, size: 20),
                                onPressed: () async {
                                  final projectId = expense.projectId;
                                  final customerId = expense.customerId;
                                  if (projectId == null || customerId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Set project + client on the expense, then bill'),
                                      ),
                                    );
                                    return;
                                  }
                                  try {
                                    final id = await ref.read(billableToInvoiceServiceProvider).createFromProject(
                                          projectId: projectId,
                                          customerId: customerId,
                                        );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Draft invoice #$id created')),
                                      );
                                      context.push('/invoices/$id/edit');
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                    }
                                  }
                                },
                              ),
                            Text(
                              formatCurrency(expense.amount),
                              style: const TextStyle(fontWeight: FontWeight.w700, color: ClivoraColors.errorRed),
                            ),
                          ],
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

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, this.expenseId});

  final int? expenseId;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _vendorController = TextEditingController();
  final _notesController = TextEditingController();
  String _category = 'other';
  String _paymentMethod = 'cash';
  DateTime _date = DateTime.now();
  int? _vendorId;
  bool _isBillable = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.expenseId != null) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    final expense = await ref.read(databaseProvider).getExpense(widget.expenseId!);
    if (expense != null && mounted) {
      _titleController.text = expense.title;
      _amountController.text = expense.amount.toString();
      _vendorController.text = expense.vendor;
      _notesController.text = expense.notes;
      _category = expense.category;
      _paymentMethod = expense.paymentMethod;
      _date = expense.expenseDate;
      _vendorId = expense.vendorId;
      _isBillable = expense.isBillable;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _vendorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    final db = ref.read(databaseProvider);
    if (widget.expenseId != null) {
      final existing = await db.getExpense(widget.expenseId!);
      if (existing != null) {
        await db.updateExpense(existing.copyWith(
          title: _titleController.text.trim(),
          amount: amount,
          category: _category,
          paymentMethod: _paymentMethod,
          vendor: _vendorController.text.trim(),
          vendorId: Value(_vendorId),
          isBillable: _isBillable,
          notes: _notesController.text.trim(),
          expenseDate: _date,
        ));
      }
    } else {
      if (!await requireEmailVerified(context, ref, actionLabel: 'add expenses')) {
        return;
      }
      await db.insertExpense(ExpensesCompanion.insert(
        ownerUserId: ref.read(authStateProvider).valueOrNull!.id,
        title: _titleController.text.trim(),
        amount: amount,
        category: Value(_category),
        paymentMethod: Value(_paymentMethod),
        vendor: Value(_vendorController.text.trim()),
        vendorId: Value(_vendorId),
        isBillable: Value(_isBillable),
        notes: Value(_notesController.text.trim()),
        expenseDate: Value(_date),
      ));
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expenseId != null ? 'Edit Expense' : 'New Expense'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'TITLE', hintText: 'Expense title'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'AMOUNT', hintText: '0.00'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'CATEGORY'),
            items: expenseCategories
                .where((c) => c != 'all')
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c[0].toUpperCase() + c.substring(1)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? 'other'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _paymentMethod,
            decoration: const InputDecoration(labelText: 'PAYMENT METHOD'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'card', child: Text('Card')),
              DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
            ],
            onChanged: (v) => setState(() => _paymentMethod = v ?? 'cash'),
          ),
          const SizedBox(height: 16),
          ref.watch(vendorsProvider).when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (vendors) {
              if (vendors.isEmpty) {
                return TextField(
                  controller: _vendorController,
                  decoration: const InputDecoration(labelText: 'VENDOR', hintText: 'Optional'),
                );
              }
              return DropdownButtonFormField<int?>(
                initialValue: _vendorId,
                decoration: const InputDecoration(labelText: 'VENDOR'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('None / custom')),
                  ...vendors.map((v) => DropdownMenuItem(value: v.id, child: Text(v.name))),
                ],
                onChanged: (id) {
                  setState(() {
                    _vendorId = id;
                    if (id != null) {
                      final v = vendors.firstWhere((e) => e.id == id);
                      _vendorController.text = v.name;
                    }
                  });
                },
              );
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _vendorController,
            decoration: const InputDecoration(labelText: 'VENDOR NAME', hintText: 'Optional free text'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Billable to client'),
            subtitle: const Text('Include when converting project work to an invoice'),
            value: _isBillable,
            onChanged: (v) => setState(() => _isBillable = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'NOTES', hintText: 'Optional'),
          ),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: _save, child: const Text('Save Expense')),
        ],
      ),
    );
  }
}
