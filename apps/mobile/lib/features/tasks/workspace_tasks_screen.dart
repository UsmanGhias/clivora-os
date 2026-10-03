import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud/cloud_workspace_tasks_repository.dart';
import '../../core/cloud/supabase_auth_helper.dart';
import '../../core/services/feature_flags_service.dart';
import '../../shared/widgets/clivora_scaffold.dart';

/// Freelancer cloud workspace tasks (matches web /app/workspace-tasks).
class WorkspaceTasksScreen extends ConsumerStatefulWidget {
  const WorkspaceTasksScreen({super.key});

  @override
  ConsumerState<WorkspaceTasksScreen> createState() => _WorkspaceTasksScreenState();
}

class _WorkspaceTasksScreenState extends ConsumerState<WorkspaceTasksScreen> {
  bool? _enabled;
  List<Map<String, dynamic>> _rows = [];
  final _title = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final on = await ref.read(featureFlagsServiceProvider).workspaceTasks();
    if (!mounted) return;
    setState(() => _enabled = on);
    if (!on) return;
    try {
      final uid = SupabaseAuthHelper.currentUid;
      if (uid == null) return;
      final rows = await SupabaseAuthHelper.client
          .from('workspace_tasks')
          .select()
          .or('owner_uid.eq.$uid,shared_with_uid.eq.$uid')
          .order('updated_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows as List);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClivoraScaffold(
      title: 'Workspace tasks',
      subtitle: 'Cloud tasks synced with web when enabled',
      showBackButton: true,
      body: _enabled == null
          ? const Center(child: CircularProgressIndicator())
          : !_enabled!
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Workspace tasks flag is off. Local tasks remain at Tasks.'),
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Back'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _title,
                            decoration: const InputDecoration(
                              labelText: 'Task title',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  if (_title.text.trim().isEmpty) return;
                                  setState(() => _busy = true);
                                  try {
                                    final uid = SupabaseAuthHelper.currentUid;
                                    if (uid == null) throw StateError('Sign in required');
                                    await SupabaseAuthHelper.client.from('workspace_tasks').insert({
                                      'owner_uid': uid,
                                      'title': _title.text.trim(),
                                      'status': 'pending',
                                      'priority': 'medium',
                                      'updated_at': DateTime.now().toUtc().toIso8601String(),
                                    });
                                    _title.clear();
                                    await _load();
                                    // Also try Drift push path when local id exists later.
                                    await ref.read(cloudWorkspaceTasksRepositoryProvider).isEnabled();
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
                    const SizedBox(height: 12),
                    ..._rows.map(
                      (t) => Card(
                        child: ListTile(
                          title: Text('${t['title']}'),
                          subtitle: Text('${t['status']} · ${t['priority']}${t['is_milestone'] == true ? ' · milestone' : ''}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _busy
                                ? null
                                : () async {
                                    setState(() => _busy = true);
                                    try {
                                      await SupabaseAuthHelper.client
                                          .from('workspace_tasks')
                                          .delete()
                                          .eq('id', t['id']);
                                      await _load();
                                    } catch (e) {
                                      setState(() => _error = '$e');
                                    } finally {
                                      if (mounted) setState(() => _busy = false);
                                    }
                                  },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
