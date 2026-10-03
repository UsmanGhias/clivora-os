import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/entity_attachment_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../data/database/database.dart';

/// Attachments panel for invoices, projects, contracts, and customers.
class EntityAttachmentsPanel extends ConsumerWidget {
  const EntityAttachmentsPanel({
    super.key,
    required this.entityType,
    required this.entityId,
  });

  final String entityType;
  final int entityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachmentsAsync = ref.watch(
      entityAttachmentsProvider(EntityAttachmentQuery(entityType: entityType, entityId: entityId)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.attach_file_rounded, size: 18, color: ClivoraColors.primary),
            const SizedBox(width: 8),
            Text('Attachments', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                await ref.read(entityAttachmentServiceProvider).pickAndAttach(
                      entityType: entityType,
                      entityId: entityId,
                    );
                ref.invalidate(entityAttachmentsProvider(
                  EntityAttachmentQuery(entityType: entityType, entityId: entityId),
                ));
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        attachmentsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Could not load attachments'),
          data: (files) {
            if (files.isEmpty) {
              return Text(
                'Attach receipts, PDFs, screenshots, or project files.',
                style: Theme.of(context).textTheme.bodySmall,
              );
            }
            return Column(
              children: files.map((f) => _AttachmentTile(file: f, entityType: entityType, entityId: entityId)).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _AttachmentTile extends ConsumerWidget {
  const _AttachmentTile({
    required this.file,
    required this.entityType,
    required this.entityId,
  });

  final FileAttachment file;
  final String entityType;
  final int entityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isImage = file.mimeType.startsWith('image/');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: isImage && File(file.localPath).existsSync()
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(file.localPath), width: 44, height: 44, fit: BoxFit.cover),
            )
          : const Icon(Icons.insert_drive_file_outlined),
      title: Text(file.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(EntityAttachmentService.formatSize(file.sizeBytes)),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 20),
        onPressed: () async {
          await ref.read(entityAttachmentServiceProvider).deleteAttachment(file);
          ref.invalidate(entityAttachmentsProvider(
            EntityAttachmentQuery(entityType: entityType, entityId: entityId),
          ));
        },
      ),
    );
  }
}
