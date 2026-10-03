import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/services/backup_restore_service.dart';
import '../../core/services/cloud_crm_backup_service.dart';
import '../../core/services/last_login_service.dart';
import '../../shared/widgets/clivora_scaffold.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  final _passwordCtrl = TextEditingController();
  bool _usePassword = false;
  bool _cloudBusy = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metaAsync = ref.watch(lastBackupMetaProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ClivoraScaffold(
      title: 'Backup & Restore',
      showBackButton: true,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Text(
              'Keep your clients, projects, and invoices safe. Cloud backup restores after reinstall when you sign in again.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: onSurface.withValues(alpha: 0.75),
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 16),
            metaAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (meta) {
                if (meta.at == null) return const SizedBox.shrink();
                final sizeKb = ((meta.bytes ?? 0) / 1024).toStringAsFixed(1);
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Last local backup'),
                    subtitle: Text('${DateFormat.yMMMd().add_jm().format(meta.at!.toLocal())} · $sizeKb KB'),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('Cloud CRM backup'),
                subtitle: const Text('Saved to your CLIVORA account'),
                trailing: _cloudBusy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
                onTap: _cloudBusy
                    ? null
                    : () async {
                        setState(() => _cloudBusy = true);
                        try {
                          await ref.read(cloudCrmBackupServiceProvider).uploadCurrentWorkspace();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cloud backup saved')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        } finally {
                          if (mounted) setState(() => _cloudBusy = false);
                        }
                      },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: const Text('Restore from cloud'),
                subtitle: const Text('Use after reinstall if local data is empty'),
                onTap: _cloudBusy
                    ? null
                    : () async {
                        setState(() => _cloudBusy = true);
                        try {
                          final backup = await ref.read(cloudCrmBackupServiceProvider).fetchLatestBackup();
                          if (backup == null) throw StateError('No cloud backup found');
                          final n = await ref.read(backupRestoreServiceProvider).importWorkspace(backup);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Restored $n records from cloud')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        } finally {
                          if (mounted) setState(() => _cloudBusy = false);
                        }
                      },
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Password-protect file export'),
              value: _usePassword,
              onChanged: (v) => setState(() => _usePassword = v),
            ),
            if (_usePassword)
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'BACKUP PASSWORD',
                  hintText: 'Required to open this file later',
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                try {
                  await ref.read(backupRestoreServiceProvider).shareExport(
                        password: _usePassword ? _passwordCtrl.text : null,
                      );
                  ref.invalidate(lastBackupMetaProvider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
                  }
                }
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Share JSON backup file'),
            ),
            const SizedBox(height: 12),
            Text(
              'Tip: uninstalling deletes local SQLite. Use Cloud backup or a shared JSON file before switching phones.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: onSurface.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
