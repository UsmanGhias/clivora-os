import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/services/sync_outbox_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../data/database/database.dart';
import '../../shared/widgets/clivora_scaffold.dart';

/// User-visible sync queue: pending, retrying, conflicts, permanent failures.
class SyncCenterScreen extends ConsumerStatefulWidget {
  const SyncCenterScreen({super.key});

  @override
  ConsumerState<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends ConsumerState<SyncCenterScreen> {
  bool _loading = true;
  List<SyncOutboxEntry> _entries = [];
  List<Map<String, dynamic>> _conflicts = [];
  DateTime? _lastSync;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final outbox = ref.read(syncOutboxServiceProvider);
      await outbox.ensureMigrated();
      final entries = await outbox.listVisibleEntries();
      final conflicts = await outbox.pendingConflicts();
      final last = await outbox.lastSyncAt();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _conflicts = conflicts;
        _lastSync = last;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _process() async {
    await ref.read(syncOutboxServiceProvider).processQueue();
    await _reload();
  }

  Future<void> _retryFailed() async {
    await ref.read(syncOutboxServiceProvider).retryPermanentlyFailed();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd().add_jm();
    return ClivoraScaffold(
      title: 'Sync Center',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offline sync integrity',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _lastSync == null
                                ? 'Last successful sync: not yet'
                                : 'Last successful sync: ${fmt.format(_lastSync!.toLocal())}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: _process,
                                icon: const Icon(Icons.sync),
                                label: const Text('Sync now'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _retryFailed,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry failures'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await showEntityConflictDialog(context, ref);
                                  await _reload();
                                },
                                icon: const Icon(Icons.merge_type),
                                label: Text('Resolve conflicts (${_conflicts.length})'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Conflicts (${_conflicts.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if (_conflicts.isEmpty)
                    const Text('No pending conflicts.')
                  else
                    ..._conflicts.map((c) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                          title: Text('${c['entityType']} #${c['localId']}'),
                          subtitle: Text(
                            'Local: ${c['localStatus']} · Cloud: ${c['cloudStatus']}',
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              await showEntityConflictDialog(context, ref);
                              await _reload();
                            },
                            child: const Text('Resolve'),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 16),
                  Text(
                    'Queue (${_entries.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if (_entries.isEmpty)
                    const Text('Queue is empty - all caught up.')
                  else
                    ..._entries.map((e) {
                      final color = switch (e.status) {
                        'permanently_failed' => Colors.red,
                        'conflicted' => Colors.amber,
                        'retrying' => Colors.orange,
                        'processing' => ClivoraColors.primary,
                        'completed' => Colors.green,
                        _ => Colors.blueGrey,
                      };
                      return Card(
                        child: ListTile(
                          leading: Icon(Icons.outbox, color: color),
                          title: Text('${e.kind} · ${e.status}'),
                          subtitle: Text(
                            [
                              'id ${e.operationId.substring(0, 8)}…',
                              'retries ${e.retries}',
                              if (e.lastError != null) e.lastError!,
                              'updated ${fmt.format(e.updatedAt.toLocal())}',
                            ].join('\n'),
                          ),
                          isThreeLine: true,
                          trailing: e.status == 'permanently_failed' ||
                                  e.status == 'retrying' ||
                                  e.status == 'pending'
                              ? IconButton(
                                  tooltip: 'Retry',
                                  onPressed: () async {
                                    await ref.read(syncOutboxServiceProvider).retryOne(e.id);
                                    await _reload();
                                  },
                                  icon: const Icon(Icons.replay),
                                )
                              : null,
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
