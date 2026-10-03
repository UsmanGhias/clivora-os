import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud/cloud_crm_conflicts_repository.dart';
import '../../core/services/feature_flags_service.dart';
import '../../shared/widgets/clivora_scaffold.dart';

class CrmConflictsScreen extends ConsumerStatefulWidget {
  const CrmConflictsScreen({super.key});

  @override
  ConsumerState<CrmConflictsScreen> createState() => _CrmConflictsScreenState();
}

class _CrmConflictsScreenState extends ConsumerState<CrmConflictsScreen> {
  bool? _enabled;
  List<Map<String, dynamic>> _rows = [];
  String? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final on = await ref.read(featureFlagsServiceProvider).crmConflicts();
    if (!mounted) return;
    setState(() => _enabled = on);
    if (!on) return;
    try {
      final rows = await ref.read(cloudCrmConflictsRepositoryProvider).listOpen();
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
      title: 'CRM sync conflicts',
      subtitle: 'Keep local or Take cloud (web parity)',
      showBackButton: true,
      body: _enabled == null
          ? const Center(child: CircularProgressIndicator())
          : !_enabled!
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Conflict UI is behind a feature flag and not enabled yet.'),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                    if (_rows.isEmpty)
                      const Text('No open conflicts.')
                    else
                      ..._rows.map((r) {
                        final id = '${r['id']}';
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '${r['entity_type']}${r['local_id'] != null ? ' #${r['local_id']}' : ''}',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Local: ${const JsonEncoder.withIndent('  ').convert(r['local_snapshot'])}',
                                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                ),
                                Text(
                                  'Cloud: ${const JsonEncoder.withIndent('  ').convert(r['cloud_snapshot'])}',
                                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                ),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: _busyId == id
                                          ? null
                                          : () async {
                                              setState(() => _busyId = id);
                                              try {
                                                await ref
                                                    .read(cloudCrmConflictsRepositoryProvider)
                                                    .resolve(id, resolution: 'keep_local');
                                                await _load();
                                              } catch (e) {
                                                setState(() => _error = '$e');
                                              } finally {
                                                if (mounted) setState(() => _busyId = null);
                                              }
                                            },
                                      child: const Text('Keep local'),
                                    ),
                                    TextButton(
                                      onPressed: _busyId == id
                                          ? null
                                          : () async {
                                              setState(() => _busyId = id);
                                              try {
                                                await ref
                                                    .read(cloudCrmConflictsRepositoryProvider)
                                                    .resolve(id, resolution: 'take_cloud');
                                                await _load();
                                              } catch (e) {
                                                setState(() => _error = '$e');
                                              } finally {
                                                if (mounted) setState(() => _busyId = null);
                                              }
                                            },
                                      child: const Text('Take cloud'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
    );
  }
}
