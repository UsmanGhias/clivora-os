import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/user_roles.dart';
import '../../core/cloud/cloud_message_repository.dart';
import '../../core/cloud/supabase_auth_helper.dart';
import '../../core/theme/clivora_colors.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';

/// Freelancer ↔ client messaging (Supabase realtime).
class FreelancerMessagesScreen extends ConsumerWidget {
  const FreelancerMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mailboxAsync = ref.watch(freelancerMailboxProvider);

    return ClivoraScaffold(
      title: 'Client Messages',
      action: IconButton(
        icon: const Icon(Icons.edit_outlined),
        tooltip: 'New message',
        onPressed: () => _showComposeDialog(context, ref),
      ),
      body: mailboxAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (messages) {
          if (messages.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.forum_outlined, size: 56, color: ClivoraColors.labelGray),
                    const SizedBox(height: 16),
                    Text('No messages yet', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Send updates to clients from here or when you add a customer. Clients can reply from their app.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => _showComposeDialog(context, ref),
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Message a client'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: messages.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _MailboxTile(message: messages[index]),
          );
        },
      ),
    );
  }

  Future<void> _showComposeDialog(BuildContext context, WidgetRef ref) async {
    final emailCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Message client'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Client email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject')),
              TextField(
                controller: bodyCtrl,
                decoration: const InputDecoration(labelText: 'Message'),
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (sent != true || !context.mounted) return;

    final fromUser = ref.read(authStateProvider).valueOrNull;
    if (fromUser == null || isGuestUser(fromUser)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to send cloud messages')),
      );
      return;
    }

    final toEmail = emailCtrl.text.trim();
    if (toEmail.isEmpty || bodyCtrl.text.trim().isEmpty) return;

    await ref.read(cloudMessageRepositoryProvider).sendHybrid(
          fromUser: fromUser,
          toEmail: toEmail,
          subject: subjectCtrl.text.trim(),
          body: bodyCtrl.text.trim(),
        );
    if (context.mounted) {
      ref.invalidate(freelancerMailboxProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message sent')));
    }
  }
}

class _MailboxTile extends ConsumerWidget {
  const _MailboxTile({required this.message});

  final CloudMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = SupabaseAuthHelper.currentUid;
    final isFromMe = message.fromUid == uid;
    final time = DateFormat('MMM d · h:mm a').format(message.createdAt.toLocal());
    final peer = isFromMe ? message.toEmail : message.fromEmail;

    return InkWell(
      onTap: () async {
        if (!message.isRead && !isFromMe) {
          await SupabaseAuthHelper.client
              .from('client_messages')
              .update({'is_read': true})
              .eq('id', message.id);
          ref.invalidate(freelancerMailboxProvider);
          ref.invalidate(freelancerUnreadProvider);
        }
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(message.subject.isNotEmpty ? message.subject : 'Message'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('With: $peer', style: Theme.of(ctx).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Text(message.body),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: !message.isRead && !isFromMe
                ? ClivoraColors.primary.withValues(alpha: 0.35)
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isFromMe ? Icons.call_made_rounded : Icons.call_received_rounded,
              size: 18,
              color: isFromMe ? ClivoraColors.labelGray : ClivoraColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.subject.isNotEmpty ? message.subject : 'Project update',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(peer, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Text(
                    message.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(time, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ClivoraColors.labelGray)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
