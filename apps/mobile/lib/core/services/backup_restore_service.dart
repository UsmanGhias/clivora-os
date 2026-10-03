import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../auth/auth_service.dart';
import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import 'last_login_service.dart';

final backupRestoreServiceProvider = Provider<BackupRestoreService>((ref) {
  return BackupRestoreService(ref);
});

const _backupSchemaVersion = 1;

/// Export and restore workspace data as JSON for confidence and support.
class BackupRestoreService {
  BackupRestoreService(this.ref);

  final Ref ref;

  Future<Map<String, dynamic>> exportWorkspace() async {
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) throw StateError('Sign in to export');

    final db = ref.read(databaseProvider);
    final customers = await db.watchCustomersForUser(ownerId).first;
    final projects = await db.watchProjectsForUser(ownerId).first;
    final invoices = await db.watchInvoicesForUser(ownerId).first;
    final tasks = await db.watchTasksForUser(ownerId).first;
    final notes = await db.watchNotesForUser(ownerId).first;
    final contracts = await db.watchContractsForUser(ownerId).first;
    final templates = await db.watchMessageTemplatesForUser(ownerId).first;
    final tracking = await db.watchAllTrackingForUser(ownerId);
    final attachments = await db.watchAllAttachmentsForUser(ownerId);

    final payload = {
      'schemaVersion': _backupSchemaVersion,
      'version': _backupSchemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'ownerUserId': ownerId,
      'customers': customers.map(_customerJson).toList(),
      'projects': projects.map(_projectJson).toList(),
      'invoices': invoices.map(_invoiceJson).toList(),
      'tasks': tasks.map(_taskJson).toList(),
      'notes': notes.map(_noteJson).toList(),
      'contracts': contracts.map(_contractJson).toList(),
      'templates': templates.map(_templateJson).toList(),
      'tracking': tracking.map(_trackingJson).toList(),
      'attachments': attachments.map(_attachmentJson).toList(),
    };
    payload['checksum'] = _checksum(jsonEncode(payload));
    return payload;
  }

  Future<void> shareExport({String? password}) async {
    final data = await exportWorkspace();
    var content = jsonEncode(data);
    if (password != null && password.isNotEmpty) {
      content = jsonEncode({
        'encrypted': true,
        'payload': _encrypt(content, password),
      });
    }
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'clivora_backup_${DateTime.now().millisecondsSinceEpoch}.json'));
    await file.writeAsString(content);
    await BackupMetaService.recordExport(content.length);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'CLIVORA workspace backup'),
    );
  }

  Map<String, dynamic> decodeImportFile(String raw, {String? password}) {
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    if (parsed['encrypted'] == true) {
      if (password == null || password.isEmpty) {
        throw FormatException('This backup is password-protected');
      }
      final decrypted = _decrypt(parsed['payload'] as String, password);
      return jsonDecode(decrypted) as Map<String, dynamic>;
    }
    return parsed;
  }

  String _encrypt(String plain, String password) {
    final key = sha256.convert(utf8.encode(password)).bytes;
    final bytes = utf8.encode(plain);
    final out = List<int>.generate(bytes.length, (i) => bytes[i] ^ key[i % key.length]);
    return base64Encode(out);
  }

  String _decrypt(String encoded, String password) {
    final key = sha256.convert(utf8.encode(password)).bytes;
    final bytes = base64Decode(encoded);
    final out = List<int>.generate(bytes.length, (i) => bytes[i] ^ key[i % key.length]);
    return utf8.decode(out);
  }

  Future<void> shareExportLegacy() async => shareExport();

  void validateBackup(Map<String, dynamic> data, {required int currentUserId}) {
    final version = data['schemaVersion'] ?? data['version'];
    if (version == null || (version is int && version > _backupSchemaVersion)) {
      throw FormatException('Unsupported backup version');
    }
    final owner = data['ownerUserId'];
    if (owner != null && owner != currentUserId) {
      throw FormatException('Backup belongs to a different account');
    }
    final checksum = data['checksum'] as String?;
    if (checksum != null) {
      final copy = Map<String, dynamic>.from(data)..remove('checksum');
      final expected = _checksum(jsonEncode(copy));
      if (checksum != expected) {
        throw FormatException('Backup file failed integrity check');
      }
    }
  }

  Future<int> importWorkspace(Map<String, dynamic> data) async {
    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) throw StateError('Sign in to import');
    validateBackup(data, currentUserId: ownerId);

    final limits = ref.read(planLimitServiceProvider);
    final db = ref.read(databaseProvider);
    var imported = 0;

    for (final row in (data['customers'] as List? ?? [])) {
      if (!await limits.canAddCustomer()) break;
      await db.insertCustomer(CustomersCompanion.insert(
        ownerUserId: ownerId,
        contactPerson: row['contactPerson'] as String? ?? 'Client',
        company: Value(row['company'] as String? ?? ''),
        emails: Value(row['emails'] as String? ?? '[]'),
      ));
      imported++;
    }

    for (final row in (data['templates'] as List? ?? [])) {
      if (!await limits.canAddTemplate()) break;
      await db.insertMessageTemplate(MessageTemplatesCompanion.insert(
        ownerUserId: ownerId,
        name: row['name'] as String? ?? 'Template',
        category: Value(row['category'] as String? ?? 'general'),
        subject: Value(row['subject'] as String? ?? ''),
        body: Value(row['body'] as String? ?? ''),
      ));
      imported++;
    }

    for (final row in (data['notes'] as List? ?? [])) {
      await db.insertNote(NotesCompanion.insert(
        ownerUserId: ownerId,
        title: row['title'] as String? ?? 'Note',
        content: Value(row['content'] as String? ?? ''),
        type: Value(row['type'] as String? ?? 'general'),
      ));
      imported++;
    }

    // Placeholder client for restored projects/invoices/contracts that need customerId.
    int? restoreCustomerId;
    final existingCustomers = await db.watchCustomersForUser(ownerId).first;
    if (existingCustomers.isNotEmpty) {
      restoreCustomerId = existingCustomers.first.id;
    }

    for (final row in (data['projects'] as List? ?? [])) {
      if (restoreCustomerId == null) break;
      if (!await limits.canAddProject()) break;
      await db.insertProject(ProjectsCompanion.insert(
        ownerUserId: ownerId,
        customerId: restoreCustomerId,
        name: row['name'] as String? ?? 'Project',
        status: Value(row['status'] as String? ?? 'active'),
        budget: Value((row['budget'] as num?)?.toDouble() ?? 0),
        currency: Value(row['currency'] as String? ?? 'PKR'),
      ));
      imported++;
    }

    for (final row in (data['invoices'] as List? ?? [])) {
      if (restoreCustomerId == null) break;
      if (!await limits.canAddInvoice()) break;
      await db.insertInvoice(InvoicesCompanion.insert(
        ownerUserId: ownerId,
        customerId: restoreCustomerId,
        invoiceNumber: row['invoiceNumber'] as String? ?? 'INV-${imported + 1}',
        status: Value(row['status'] as String? ?? 'draft'),
        total: Value((row['total'] as num?)?.toDouble() ?? 0),
        currency: Value(row['currency'] as String? ?? 'PKR'),
      ));
      imported++;
    }

    for (final row in (data['tasks'] as List? ?? [])) {
      await db.insertTask(TasksCompanion.insert(
        ownerUserId: ownerId,
        title: row['title'] as String? ?? 'Task',
        completed: Value(row['completed'] as bool? ?? false),
        priority: Value(row['priority'] as String? ?? 'medium'),
      ));
      imported++;
    }

    for (final row in (data['contracts'] as List? ?? [])) {
      if (restoreCustomerId == null) break;
      await db.insertContract(ContractsCompanion.insert(
        ownerUserId: ownerId,
        customerId: restoreCustomerId,
        title: row['title'] as String? ?? 'Contract',
        status: Value(row['status'] as String? ?? 'draft'),
      ));
      imported++;
    }

    return imported;
  }

  String _checksum(String raw) => raw.hashCode.toRadixString(16);

  Map<String, dynamic> _customerJson(Customer c) => {
        'contactPerson': c.contactPerson,
        'company': c.company,
        'emails': c.emails,
        'phones': c.phones,
        'status': c.status,
      };

  Map<String, dynamic> _projectJson(Project p) => {
        'name': p.name,
        'status': p.status,
        'budget': p.budget,
        'currency': p.currency,
      };

  Map<String, dynamic> _invoiceJson(Invoice i) => {
        'invoiceNumber': i.invoiceNumber,
        'status': i.status,
        'total': i.total,
        'currency': i.currency,
      };

  Map<String, dynamic> _taskJson(Task t) => {
        'title': t.title,
        'completed': t.completed,
        'priority': t.priority,
      };

  Map<String, dynamic> _noteJson(Note n) => {
        'title': n.title,
        'content': n.content,
        'type': n.type,
      };

  Map<String, dynamic> _contractJson(Contract c) => {
        'title': c.title,
        'status': c.status,
      };

  Map<String, dynamic> _templateJson(MessageTemplate t) => {
        'name': t.name,
        'category': t.category,
        'subject': t.subject,
        'body': t.body,
      };

  Map<String, dynamic> _trackingJson(TrackingEvent e) => {
        'entityType': e.entityType,
        'entityId': e.entityId,
        'status': e.status,
        'note': e.note,
        'createdAt': e.createdAt.toIso8601String(),
      };

  Map<String, dynamic> _attachmentJson(FileAttachment a) => {
        'entityType': a.entityType,
        'entityId': a.entityId,
        'fileName': a.fileName,
        'localPath': a.localPath,
      };
}
