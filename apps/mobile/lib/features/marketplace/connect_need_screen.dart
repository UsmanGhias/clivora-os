import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/marketplace/connect_marketplace_service.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';

class ConnectNeedScreen extends ConsumerStatefulWidget {
  const ConnectNeedScreen({super.key});

  @override
  ConsumerState<ConnectNeedScreen> createState() => _ConnectNeedScreenState();
}

class _ConnectNeedScreenState extends ConsumerState<ConnectNeedScreen> {
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _skills = TextEditingController();
  String _budget = '\$500-1,500';
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _skills.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasAccess = ref.watch(isProPlusProvider);
    return ClivoraScaffold(
      title: 'Post a job',
      showBackButton: true,
      body: !hasAccess
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 44,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Connect requires Pro Plus',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.push('/upgrade'),
                    child: const Text('Upgrade to Pro Plus'),
                  ),
                ],
              ),
            )
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Stay anonymous until you accept a freelancer. Describe the work, not your company email.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 16),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Job title')),
          const SizedBox(height: 12),
          TextField(controller: _summary, maxLines: 4, decoration: const InputDecoration(labelText: 'Summary')),
          const SizedBox(height: 12),
          TextField(controller: _skills, decoration: const InputDecoration(labelText: 'Skills needed (comma separated)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_budget),
            initialValue: _budget,
            decoration: const InputDecoration(labelText: 'Budget band'),
            items: const [
              DropdownMenuItem(value: 'Under \$500', child: Text('Under \$500')),
              DropdownMenuItem(value: '\$500-1,500', child: Text('\$500-1,500')),
              DropdownMenuItem(value: '\$1,500-5,000', child: Text('\$1,500-5,000')),
              DropdownMenuItem(value: '\$5,000+', child: Text('\$5,000+')),
              DropdownMenuItem(value: 'negotiable', child: Text('Negotiable')),
            ],
            onChanged: (v) => setState(() => _budget = v ?? _budget),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Posting…' : 'Publish job'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final skills = _skills.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      await ref.read(connectMarketplaceServiceProvider).createNeedPost(
            title: _title.text,
            summary: _summary.text,
            skills: skills,
            budgetBand: _budget,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job posted')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
