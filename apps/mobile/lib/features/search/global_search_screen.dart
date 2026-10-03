import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/constants/invoice_statuses.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/utils/navigation_helper.dart';
import '../../data/database/database.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';

/// Global search across customers, projects, invoices, tasks, messages, and contracts.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  String _entityFilter = 'all';
  String _statusFilter = 'all';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authStateProvider).valueOrNull?.id;
    if (userId == null) {
      return const ClivoraScaffold(title: 'Search', showBackButton: true, body: Center(child: Text('Sign in to search')));
    }

    final q = _query.toLowerCase();
    final customers = ref.watch(customersProvider(_query.isEmpty ? null : _query)).valueOrNull ?? [];
    final projects = ref.watch(projectsProvider(ProjectFilter(
      search: _query.isEmpty ? null : _query,
      status: _statusFilter == 'all' ? 'all' : _statusFilter,
    ))).valueOrNull ?? [];
    final allInvoices = ref.watch(invoicesProvider(_statusFilter == 'all' || _statusFilter == 'outstanding' ? null : _statusFilter)).valueOrNull ?? [];
    final invoices = _query.isEmpty
        ? allInvoices.where((i) => _statusFilter == 'all' || i.status == _statusFilter || (_statusFilter == 'outstanding' && InvoiceStatuses.outstanding.contains(i.status))).toList()
        : allInvoices.where((i) =>
            i.invoiceNumber.toLowerCase().contains(q) ||
            i.status.toLowerCase().contains(q)).toList();
    final tasks = ref.watch(tasksProvider(TaskFilter(
      status: _statusFilter == 'completed'
          ? 'completed'
          : _statusFilter == 'pending'
              ? 'pending'
              : 'all',
    ))).valueOrNull ?? [];
    final contracts = ref.watch(contractsProvider(_statusFilter == 'all' ? null : _statusFilter)).valueOrNull ?? [];
    final notes = ref.watch(notesProvider(null)).valueOrNull ?? [];

    final filteredTasks = _query.isEmpty
        ? tasks
        : tasks.where((t) => t.title.toLowerCase().contains(q) || t.description.toLowerCase().contains(q)).toList();
    final filteredContracts = _query.isEmpty
        ? contracts
        : contracts.where((c) => c.title.toLowerCase().contains(q)).toList();
    final filteredNotes = _query.isEmpty
        ? <Note>[]
        : notes.where((n) => n.title.toLowerCase().contains(q) || n.content.toLowerCase().contains(q)).toList();

    final showCustomers = _entityFilter == 'all' || _entityFilter == 'customers';
    final showProjects = _entityFilter == 'all' || _entityFilter == 'projects';
    final showInvoices = _entityFilter == 'all' || _entityFilter == 'invoices';
    final showTasks = _entityFilter == 'all' || _entityFilter == 'tasks';
    final showContracts = _entityFilter == 'all' || _entityFilter == 'contracts';
    final showMessages = _entityFilter == 'all' || _entityFilter == 'messages';

    return ClivoraScaffold(
      title: 'Search',
      showBackButton: true,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search everything…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final opt in ['all', 'customers', 'projects', 'invoices', 'tasks', 'contracts', 'messages'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(opt == 'all' ? 'All' : opt[0].toUpperCase() + opt.substring(1)),
                      selected: _entityFilter == opt,
                      showCheckmark: true,
                      selectedColor: ClivoraColors.primary,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: _entityFilter == opt ? Colors.white : Theme.of(context).colorScheme.onSurface,
                        fontWeight: _entityFilter == opt ? FontWeight.w600 : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: _entityFilter == opt ? ClivoraColors.primary : Theme.of(context).dividerColor,
                      ),
                      onSelected: (_) => setState(() => _entityFilter = opt),
                    ),
                  ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                for (final opt in ['all', 'active', 'completed', 'outstanding', 'overdue', 'draft'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(opt == 'all' ? 'Any status' : opt[0].toUpperCase() + opt.substring(1)),
                      selected: _statusFilter == opt,
                      showCheckmark: true,
                      selectedColor: ClivoraColors.primary,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: _statusFilter == opt ? Colors.white : Theme.of(context).colorScheme.onSurface,
                        fontWeight: _statusFilter == opt ? FontWeight.w600 : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: _statusFilter == opt ? ClivoraColors.primary : Theme.of(context).dividerColor,
                      ),
                      onSelected: (_) => setState(() => _statusFilter = opt),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _query.isEmpty && _entityFilter == 'all'
                ? const Center(
                    child: Text('Type to search or pick filters', style: TextStyle(color: ClivoraColors.textSecondary)),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (showCustomers && customers.isNotEmpty) ...[
                        _SectionHeader('Clients (${customers.length})'),
                        ...customers.take(10).map((c) => _ResultTile(
                              icon: Icons.person_outline,
                              title: c.contactPerson,
                              subtitle: c.company.isNotEmpty ? c.company : c.emails,
                              onTap: () => openFormRoute(context, '/customers/${c.id}/edit'),
                            )),
                      ],
                      if (showProjects && projects.isNotEmpty) ...[
                        _SectionHeader('Projects (${projects.length})'),
                        ...projects.take(10).map((p) => _ResultTile(
                              icon: Icons.folder_outlined,
                              title: p.name,
                              subtitle: p.status,
                              onTap: () => openFormRoute(context, '/projects/${p.id}/edit'),
                            )),
                      ],
                      if (showInvoices && invoices.isNotEmpty) ...[
                        _SectionHeader('Invoices (${invoices.length})'),
                        ...invoices.take(10).map((i) => _ResultTile(
                              icon: Icons.receipt_long_outlined,
                              title: i.invoiceNumber,
                              subtitle: '${InvoiceStatuses.label(i.status)} · ${i.total.toStringAsFixed(2)}',
                              onTap: () => openFormRoute(context, '/invoices/${i.id}/edit'),
                            )),
                      ],
                      if (showTasks && filteredTasks.isNotEmpty) ...[
                        _SectionHeader('Tasks (${filteredTasks.length})'),
                        ...filteredTasks.take(10).map((t) => _ResultTile(
                              icon: Icons.task_alt_outlined,
                              title: t.title,
                              subtitle: t.completed ? 'Completed' : 'Pending',
                              onTap: () => context.push('/tasks'),
                            )),
                      ],
                      if (showContracts && filteredContracts.isNotEmpty) ...[
                        _SectionHeader('Contracts (${filteredContracts.length})'),
                        ...filteredContracts.take(10).map((c) => _ResultTile(
                              icon: Icons.description_outlined,
                              title: c.title,
                              subtitle: c.status,
                              onTap: () => context.push('/contracts'),
                            )),
                      ],
                      if (showMessages && filteredNotes.isNotEmpty) ...[
                        _SectionHeader('Notes & messages (${filteredNotes.length})'),
                        ...filteredNotes.take(10).map((n) => _ResultTile(
                              icon: Icons.chat_bubble_outline,
                              title: n.title,
                              subtitle: n.type,
                              onTap: () => context.push('/notes'),
                            )),
                      ],
                      if (customers.isEmpty && projects.isEmpty && invoices.isEmpty && filteredTasks.isEmpty && filteredContracts.isEmpty && filteredNotes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(child: Text('No results for "$_query"')),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: ClivoraColors.primary),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
