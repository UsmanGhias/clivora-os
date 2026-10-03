import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/user_roles.dart';
import '../../core/cloud/cloud_message_repository.dart';
import '../../core/cloud/cloud_notification_repository.dart';
import '../../core/theme/clivora_colors.dart';
import '../../core/constants/plan_limits.dart';
import '../../core/utils/contract_content_helper.dart';
import '../../core/utils/plan_limit_dialog.dart';
import 'package:go_router/go_router.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import 'client_contract_view.dart';

/// Contracts shared by freelancers, view terms, attachments, and sign.
class ClientContractsScreen extends ConsumerWidget {
  const ClientContractsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contractsAsync = ref.watch(clientContractsProvider);

    return ClivoraScaffold(
      title: 'Contracts',
      action: IconButton(
        icon: const Icon(Icons.add),
        tooltip: 'New contract proposal',
        onPressed: () async {
          if (!await _checkClientContractLimit(context, ref)) return;
          if (context.mounted) _createContract(context, ref);
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(clientContractsProvider);
          ref.invalidate(unifiedClientInboxProvider);
        },
        child: contractsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (contracts) {
            if (contracts.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description_outlined, size: 56, color: ClivoraColors.clientMuted),
                            const SizedBox(height: 16),
                            Text('No contracts yet', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(
                              'When your freelancer sends an agreement, it will appear here. You can also propose a new contract with +.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: () async {
                                if (!await _checkClientContractLimit(context, ref)) return;
                                if (context.mounted) _createContract(context, ref);
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Propose contract'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: contracts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _ClientContractTile(contract: contracts[index]),
            );
          },
        ),
      ),
    );
  }
}

Future<bool> _checkClientContractLimit(BuildContext context, WidgetRef ref) async {
  final contracts = await ref.read(clientContractsProvider.future);
  if (await ref.read(planLimitServiceProvider).canAddClientContract(contracts.length)) {
    return true;
  }
  if (!context.mounted) return false;
  final upgrade = await showPlanLimitDialog(
    context,
    resource: 'contracts',
    max: PlanLimits.freeMaxClientContracts,
  );
  if (upgrade && context.mounted) context.push('/upgrade');
  return false;
}

Future<void> _createContract(BuildContext context, WidgetRef ref) async {
  final titleCtrl = TextEditingController();
  final bodyCtrl = TextEditingController(text: 'Agreement terms to be defined');

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Propose contract'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Contract title'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyCtrl,
              decoration: const InputDecoration(labelText: 'Terms / scope'),
              maxLines: 5,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, titleCtrl.text.trim().isNotEmpty), child: const Text('Send')),
      ],
    ),
  );

  if (ok != true) return;

  final client = ref.read(authStateProvider).valueOrNull;
  if (client == null || !isClientUser(client)) return;

  final links = await ref.read(databaseProvider).getFreelancerLinksForClient(client.id);
  final freelancerEmail = links.isNotEmpty
      ? (await ref.read(databaseProvider).getUser(links.first.freelancerUserId))?.email
      : null;

  if (freelancerEmail == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link a freelancer first from Account')),
      );
    }
    return;
  }

  final title = titleCtrl.text.trim();
  final encoded = ContractContentHelper.encode(body: bodyCtrl.text.trim());

  await ref.read(cloudMessageRepositoryProvider).sendHybrid(
        fromUser: client,
        toEmail: freelancerEmail,
        subject: '${ClientContractView.contractPrefix} $title',
        body: encoded,
      );
  await ref.read(cloudNotificationRepositoryProvider).send(
        toEmail: freelancerEmail,
        title: 'Contract proposal: $title',
        body: '${client.name} sent a new contract proposal for review.',
        kind: 'contract',
      );

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contract proposal sent to your freelancer')),
    );
    ref.invalidate(clientContractsProvider);
    ref.invalidate(unifiedClientInboxProvider);
  }
}

class _ClientContractTile extends ConsumerWidget {
  const _ClientContractTile({required this.contract});

  final ClientContractView contract;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsed = ContractContentHelper.decode(contract.content);
    final statusColor = contract.status == 'signed'
        ? ClivoraColors.successGreen
        : contract.status == 'sent'
            ? ClivoraColors.clientAccent
            : ClivoraColors.labelGray;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openContract(context, ref, contract, parsed),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Icon(Icons.description_outlined, color: statusColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contract.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      contract.status.toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                    if (parsed.attachmentPath != null)
                      Text('Attachment included', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openContract(
    BuildContext context,
    WidgetRef ref,
    ClientContractView contract,
    ({
      String body,
      String? attachmentPath,
      String? clientSignature,
      String? signedAt,
      String? deviceMeta,
    }) parsed,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Text(contract.title, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Chip(label: Text(contract.status.replaceAll('_', ' '))),
              const SizedBox(height: 16),
              Text(parsed.body, style: Theme.of(ctx).textTheme.bodyMedium),
              if (parsed.attachmentPath != null) ...[
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.attach_file),
                  title: const Text('Attached document'),
                  subtitle: Text(parsed.attachmentPath!.split(Platform.pathSeparator).last),
                ),
              ],
              if (parsed.clientSignature != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ClivoraColors.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Signed by: ${parsed.clientSignature}'
                    '${parsed.signedAt != null ? '\nAt: ${parsed.signedAt}' : ''}'
                    '${parsed.deviceMeta != null ? '\nDevice: ${parsed.deviceMeta}' : ''}',
                  ),
                ),
              ],
              if (contract.status == 'sent') ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _signContract(ctx, ref, contract, parsed),
                  icon: const Icon(Icons.draw_rounded),
                  label: const Text('Sign agreement'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signContract(
    BuildContext context,
    WidgetRef ref,
    ClientContractView contract,
    ({
      String body,
      String? attachmentPath,
      String? clientSignature,
      String? signedAt,
      String? deviceMeta,
    }) parsed,
  ) async {
    final nameCtrl = TextEditingController();
    final signed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign contract'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Type your full name to accept this agreement.'),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Full name'),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim().isNotEmpty), child: const Text('Sign')),
        ],
      ),
    );
    if (signed != true || nameCtrl.text.trim().isEmpty) return;

    final client = ref.read(authStateProvider).valueOrNull;
    if (client == null || !isClientUser(client)) return;

    final encoded = ContractContentHelper.encode(
      body: parsed.body,
      attachmentPath: parsed.attachmentPath,
      clientSignature: nameCtrl.text.trim(),
      signedAt: DateTime.now().toUtc().toIso8601String(),
      deviceMeta: Platform.operatingSystem,
    );

    final links = await ref.read(databaseProvider).getFreelancerLinksForClient(client.id);
    final freelancerEmail = links.isNotEmpty
        ? (await ref.read(databaseProvider).getUser(links.first.freelancerUserId))?.email
        : null;

    if (freelancerEmail != null) {
      await ref.read(cloudMessageRepositoryProvider).sendHybrid(
            fromUser: client,
            toEmail: freelancerEmail,
            subject: '${ClientContractView.signedPrefix} ${contract.title}',
            body: encoded,
          );
      await ref.read(cloudNotificationRepositoryProvider).send(
            toEmail: freelancerEmail,
            title: 'Contract signed: ${contract.title}',
            body: '${client.name} signed the agreement.',
            kind: 'contract',
          );
    }

    if (contract.localContractId != null) {
      final ownerId = links.isNotEmpty ? links.first.freelancerUserId : null;
      if (ownerId != null) {
        final existing = await ref.read(databaseProvider).getContractForUser(ownerId, contract.localContractId!);
        if (existing != null) {
          await ref.read(databaseProvider).updateContract(
                existing.copyWith(content: encoded, status: 'signed', updatedAt: DateTime.now()),
              );
        }
      }
    }

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contract signed. Your freelancer has been notified')),
      );
      ref.invalidate(clientContractsProvider);
      ref.invalidate(unifiedClientInboxProvider);
    }
  }
}
