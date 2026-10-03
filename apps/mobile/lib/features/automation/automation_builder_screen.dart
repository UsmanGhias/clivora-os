import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud/cloud_automation_rules_repository.dart';
import '../../core/services/feature_flags_service.dart';
import '../../shared/widgets/clivora_scaffold.dart';

class AutomationBuilderScreen extends ConsumerStatefulWidget {
  const AutomationBuilderScreen({super.key});

  @override
  ConsumerState<AutomationBuilderScreen> createState() => _AutomationBuilderScreenState();
}

class _AutomationBuilderScreenState extends ConsumerState<AutomationBuilderScreen> {
  bool? _enabled;
  List<Map<String, dynamic>> _rows = [];
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final on = await ref.read(featureFlagsServiceProvider).automationBuilder();
    if (!mounted) return;
    setState(() => _enabled = on);
    if (!on) return;
    try {
      final rows = await ref.read(cloudAutomationRulesRepositoryProvider).list();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClivoraScaffold(
      title: 'Automation builder',
      subtitle: 'Rules enqueue durable jobs (web parity)',
      showBackButton: true,
      body: _enabled == null
          ? const Center(child: CircularProgressIndicator())
          : !_enabled!
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Automation builder is behind a feature flag and not enabled yet.'),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _name,
                            decoration: const InputDecoration(
                              labelText: 'Rule name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  if (_name.text.trim().isEmpty) return;
                                  setState(() => _busy = true);
                                  try {
                                    await ref
                                        .read(cloudAutomationRulesRepositoryProvider)
                                        .createRule(name: _name.text);
                                    _name.clear();
                                    await _load();
                                  } catch (e) {
                                    setState(() => _error = '$e');
                                  } finally {
                                    if (mounted) setState(() => _busy = false);
                                  }
                                },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._rows.map(
                      (r) => Card(
                        child: ListTile(
                          title: Text('${r['name']}'),
                          subtitle: Text(
                            '${r['trigger_type']} → ${r['action_type']} · '
                            '${r['enabled'] == true ? 'enabled' : 'disabled'}',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
