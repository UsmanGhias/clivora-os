import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';



import '../../core/cloud/cloud_message_repository.dart';

import '../../core/theme/clivora_colors.dart';

import '../../data/providers/app_providers.dart';

import '../../shared/widgets/clivora_scaffold.dart';



class ClientMessagesScreen extends ConsumerWidget {

  const ClientMessagesScreen({super.key});



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final messagesAsync = ref.watch(unifiedClientInboxProvider);



    return ClivoraScaffold(

      title: 'Messages',

      body: messagesAsync.when(

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

                    Icon(Icons.mail_outline_rounded, size: 56, color: ClivoraColors.clientMuted),

                    const SizedBox(height: 16),

                    Text('No messages yet', style: Theme.of(context).textTheme.titleMedium),

                    const SizedBox(height: 8),

                    Text(

                      'When your freelancer shares work, invoice notes, or project updates, the conversation will appear here.',

                      textAlign: TextAlign.center,

                      style: Theme.of(context).textTheme.bodySmall,

                    ),

                    const SizedBox(height: 20),

                    FilledButton.icon(

                      onPressed: () => context.push('/client-link-freelancer'),

                      icon: const Icon(Icons.person_add_alt_1_outlined),

                      label: const Text('Add your freelancer'),

                      style: FilledButton.styleFrom(

                        backgroundColor: ClivoraColors.clientAccent,

                      ),

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

            itemBuilder: (context, index) {

              final msg = messages[index];

              return _MessageTile(message: msg);

            },

          );

        },

      ),

    );

  }

}



class _MessageTile extends ConsumerWidget {

  const _MessageTile({required this.message});



  final ClientInboxEntry message;



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final time = DateFormat('MMM d · h:mm a').format(message.createdAt.toLocal());

    return InkWell(

      onTap: () async {

        await markInboxEntryRead(ref, message);

        if (!context.mounted) return;

        await showDialog<void>(

          context: context,

          builder: (ctx) => AlertDialog(

            title: Text(message.subject.isNotEmpty ? message.subject : 'Message'),

            content: SingleChildScrollView(child: Text(message.body)),

            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],

          ),

        );

        ref.invalidate(unifiedClientInboxProvider);

        ref.invalidate(unreadMessagesProvider);

      },

      borderRadius: BorderRadius.circular(16),

      child: Container(

        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(

          color: message.isRead ? Theme.of(context).cardColor : ClivoraColors.clientSurface,

          borderRadius: BorderRadius.circular(16),

          border: Border.all(

            color: message.isRead ? Theme.of(context).dividerColor : ClivoraColors.clientAccent.withValues(alpha: 0.25),

          ),

        ),

        child: Row(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Container(

              width: 10,

              height: 10,

              margin: const EdgeInsets.only(top: 6),

              decoration: BoxDecoration(

                color: message.isRead ? Colors.transparent : ClivoraColors.clientAccent,

                shape: BoxShape.circle,

              ),

            ),

            const SizedBox(width: 12),

            Expanded(

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Row(

                    children: [

                      Expanded(

                        child: Text(

                          message.subject.isNotEmpty ? message.subject : 'Project update',

                          style: TextStyle(

                            fontWeight: message.isRead ? FontWeight.w600 : FontWeight.w800,

                            fontSize: 15,

                          ),

                        ),

                      ),

                      if (message.isCloud)

                        Icon(Icons.cloud_done_outlined, size: 14, color: ClivoraColors.labelGray),

                    ],

                  ),

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

