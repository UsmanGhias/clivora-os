import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../auth/auth_service.dart';
import 'vault_service.dart';
import '../../data/database/database.dart';
import '../../data/providers/app_providers.dart';

final entityAttachmentsProvider =
    FutureProvider.family<List<FileAttachment>, EntityAttachmentQuery>((ref, query) async {
  final ownerId = ref.watch(authStateProvider).valueOrNull?.id;
  if (ownerId == null) return [];
  return ref.watch(databaseProvider).getAttachmentsForEntity(
        ownerUserId: ownerId,
        entityType: query.entityType,
        entityId: query.entityId,
      );
});

class EntityAttachmentQuery {
  const EntityAttachmentQuery({required this.entityType, required this.entityId});

  final String entityType;
  final int entityId;

  @override
  bool operator ==(Object other) =>
      other is EntityAttachmentQuery && other.entityType == entityType && other.entityId == entityId;

  @override
  int get hashCode => Object.hash(entityType, entityId);
}

final entityAttachmentServiceProvider = Provider<EntityAttachmentService>((ref) {
  return EntityAttachmentService(ref);
});

/// Attach files to invoices, contracts, projects, customers, and receipts.
class EntityAttachmentService {
  EntityAttachmentService(this.ref);

  final Ref ref;

  Future<FileAttachment?> pickAndAttach({
    required String entityType,
    required int entityId,
    ImageSource source = ImageSource.gallery,
  }) async {
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return null;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 2400, imageQuality: 88);
    if (picked == null) return null;

    final bytes = await File(picked.path).readAsBytes();
    final plan = await ref.read(planLimitServiceProvider).currentPlan();
    final vaultResult = await VaultService.saveBytes(bytes, plan: plan, ext: p.extension(picked.path));
    if (vaultResult.isQuota) {
      throw VaultQuotaException(
        'File wallet full (${VaultService.formatSize(vaultResult.used ?? 0)} / ${VaultService.formatSize(vaultResult.limit ?? VaultService.freeLimitBytes)}). Upgrade to Pro for more storage.',
      );
    }
    if (!vaultResult.ok) {
      throw Exception(vaultResult.error ?? 'Could not save file to wallet');
    }

    final destPath = vaultResult.path!;
    final size = bytes.length;
    final fileName = p.basename(picked.path);

    final id = await ref.read(databaseProvider).insertAttachment(
          FileAttachmentsCompanion.insert(
            ownerUserId: ownerId,
            entityType: entityType,
            entityId: entityId,
            fileName: fileName,
            localPath: destPath,
            mimeType: Value(_mimeForExt(p.extension(picked.path))),
            sizeBytes: Value(size),
          ),
        );

    return FileAttachment(
      id: id,
      ownerUserId: ownerId,
      entityType: entityType,
      entityId: entityId,
      fileName: fileName,
      localPath: destPath,
      mimeType: _mimeForExt(p.extension(picked.path)),
      sizeBytes: size,
      createdAt: DateTime.now(),
    );
  }

  Future<void> deleteAttachment(FileAttachment attachment) async {
    final file = File(attachment.localPath);
    if (await file.exists()) await file.delete();
    await ref.read(databaseProvider).deleteAttachment(attachment.id);
  }

  // ignore: unused_element
  Future<Directory> _attachmentDir(int ownerId, String entityType, int entityId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'attachments', '$ownerId', entityType, '$entityId'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _mimeForExt(String ext) {
    switch (ext.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  static String formatSize(int bytes) {
    return VaultService.formatSize(bytes);
  }
}

class VaultQuotaException implements Exception {
  VaultQuotaException(this.message);
  final String message;
  @override
  String toString() => message;
}
