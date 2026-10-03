import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/models/invoice_line_item.dart';
import '../../data/providers/app_providers.dart';
import '../auth/auth_service.dart';
import '../auth/user_roles.dart';
import 'cloud_crm_conflicts_repository.dart';
import 'supabase_auth_helper.dart';

final cloudCrmRepositoryProvider = Provider<CloudCrmRepository>((ref) {
  return CloudCrmRepository(ref);
});

/// Syncs local SQLite CRM rows ↔ Supabase `crm_*` tables (source of truth for web).
class CloudCrmRepository {
  CloudCrmRepository(this.ref);

  final Ref ref;

  SupabaseClient get _db => SupabaseAuthHelper.client;

  Future<void> pushCustomer({required int ownerUserId, required int localId}) async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) return;
    final row = await ref.read(databaseProvider).getCustomerForUser(ownerUserId, localId);
    if (row == null) return;
    try {
      await _upsertByLocalId(
        table: 'crm_customers',
        uid: uid,
        localId: localId,
        payload: {
          'owner_uid': uid,
          'local_id': localId,
          'contact_person': row.contactPerson,
          'company': row.company,
          'emails': parseStringList(row.emails),
          'phones': parseStringList(row.phones),
          'whatsapp': row.whatsapp,
          'address': row.address,
          'city': row.city,
          'postal_code': row.postalCode,
          'country': row.country,
          'notes': row.notes,
          'tags': parseStringList(row.tags),
          'status': row.status,
          'updated_at': row.updatedAt.toUtc().toIso8601String(),
          'created_at': row.createdAt.toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('crm_customers push failed: $e');
      rethrow;
    }
  }

  Future<void> deleteCustomerCloud({required int localId}) async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) return;
    await _db.from('crm_customers').delete().eq('owner_uid', uid).eq('local_id', localId);
  }

  Future<void> deleteProjectCloud({required int localId}) async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) return;
    await _db.from('crm_projects').delete().eq('owner_uid', uid).eq('local_id', localId);
  }

  Future<void> deleteInvoiceCloud({required int localId}) async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) return;
    await _db.from('crm_invoices').delete().eq('owner_uid', uid).eq('local_id', localId);
  }

  Future<void> pushProject({required int ownerUserId, required int localId}) async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) return;
    final row = await ref.read(databaseProvider).getProjectForUser(ownerUserId, localId);
    if (row == null) return;
    String? cloudCustomerId;
    try {
      final c = await _db
          .from('crm_customers')
          .select('id')
          .eq('owner_uid', uid)
          .eq('local_id', row.customerId)
          .maybeSingle();
      cloudCustomerId = c?['id'] as String?;
    } catch (_) {}
    await _upsertByLocalId(
      table: 'crm_projects',
      uid: uid,
      localId: localId,
      payload: {
        'owner_uid': uid,
        'local_id': localId,
        'customer_id': cloudCustomerId,
        'local_customer_id': row.customerId,
        'name': row.name,
        'description': row.description,
        'budget': row.budget,
        'currency': row.currency,
        'priority': row.priority,
        'status': row.status,
        'start_date': row.startDate?.toUtc().toIso8601String(),
        'deadline': row.deadline?.toUtc().toIso8601String(),
        'updated_at': row.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> pushInvoice({required int ownerUserId, required int localId}) async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) return;
    final row = await ref.read(databaseProvider).getInvoiceForUser(ownerUserId, localId);
    if (row == null) return;
    String? cloudCustomerId;
    String? cloudProjectId;
    try {
      final c = await _db
          .from('crm_customers')
          .select('id')
          .eq('owner_uid', uid)
          .eq('local_id', row.customerId)
          .maybeSingle();
      cloudCustomerId = c?['id'] as String?;
    } catch (_) {}
    if (row.projectId != null) {
      try {
        final p = await _db
            .from('crm_projects')
            .select('id')
            .eq('owner_uid', uid)
            .eq('local_id', row.projectId!)
            .maybeSingle();
        cloudProjectId = p?['id'] as String?;
      } catch (_) {}
    }
    List<dynamic> lineItems = [];
    try {
      lineItems = parseLineItems(row.lineItems).map((e) => e.toJson()).toList();
    } catch (_) {}
    await _upsertByLocalId(
      table: 'crm_invoices',
      uid: uid,
      localId: localId,
      payload: {
        'owner_uid': uid,
        'local_id': localId,
        'customer_id': cloudCustomerId,
        'project_id': cloudProjectId,
        'local_customer_id': row.customerId,
        'local_project_id': row.projectId,
        'invoice_number': row.invoiceNumber,
        'status': row.status,
        'subtotal': row.subtotal,
        'tax_rate': row.taxRate,
        'discount': row.discount,
        'total': row.total,
        'amount_paid': row.amountPaid,
        'subtotal_minor': (row.subtotal * 100).round(),
        'tax_minor': ((row.subtotal * row.taxRate / 100) * 100).round(),
        'discount_minor': (row.discount * 100).round(),
        'total_minor': (row.total * 100).round(),
        'amount_paid_minor': (row.amountPaid * 100).round(),
        'currency': row.currency,
        'line_items': lineItems,
        'issue_date': row.issueDate.toUtc().toIso8601String(),
        'due_date': row.dueDate?.toUtc().toIso8601String(),
        'updated_at': row.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  /// Push all local CRM rows, then pull cloud rows newer/missing locally.
  Future<void> syncAllForSignedInUser() async {
    final uid = SupabaseAuthHelper.currentUid;
    final user = ref.read(authStateProvider).valueOrNull;
    if (uid == null || user == null) return;
    // Clients consume shares/portal data - do not push local CRM into freelancer tables.
    if (isClientUser(user)) return;
    final db = ref.read(databaseProvider);
    final ownerId = user.id;

    try {
      final customers = await (db.select(db.customers)
            ..where((t) => t.ownerUserId.equals(ownerId)))
          .get();
      for (final c in customers) {
        await pushCustomer(ownerUserId: ownerId, localId: c.id);
      }
      final projects = await (db.select(db.projects)
            ..where((t) => t.ownerUserId.equals(ownerId)))
          .get();
      for (final p in projects) {
        await pushProject(ownerUserId: ownerId, localId: p.id);
      }
      final invoices = await (db.select(db.invoices)
            ..where((t) => t.ownerUserId.equals(ownerId)))
          .get();
      for (final i in invoices) {
        await pushInvoice(ownerUserId: ownerId, localId: i.id);
      }
      await pullCustomers(ownerUserId: ownerId);
      await pullProjects(ownerUserId: ownerId);
      await pullInvoices(ownerUserId: ownerId);
    } catch (e) {
      debugPrint('Cloud CRM syncAll failed: $e');
    }
  }

  Future<void> pullCustomers({required int ownerUserId}) async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) return;
    final db = ref.read(databaseProvider);
    final rows = await _db.from('crm_customers').select().eq('owner_uid', uid);
    for (final raw in rows as List) {
      final map = Map<String, dynamic>.from(raw as Map);
      final localId = (map['local_id'] as num?)?.toInt();
      final cloudUpdated =
          DateTime.tryParse(map['updated_at'] as String? ?? '')?.toLocal() ?? DateTime.now();
      final emails = encodeStringList(_asStringList(map['emails']));
      final phones = encodeStringList(_asStringList(map['phones']));
      final tags = encodeStringList(_asStringList(map['tags']));

      if (localId != null && localId > 0) {
        final existing = await db.getCustomerForUser(ownerUserId, localId);
        if (existing != null) {
          final cloudPerson = map['contact_person'] as String? ?? '';
          final cloudCompany = map['company'] as String? ?? '';
          final fieldsDiffer = cloudPerson != existing.contactPerson ||
              cloudCompany != existing.company ||
              emails != existing.emails ||
              phones != existing.phones;
          if (cloudUpdated.isAfter(existing.updatedAt)) {
            await db.updateCustomer(
              existing.copyWith(
                contactPerson: map['contact_person'] as String? ?? existing.contactPerson,
                company: map['company'] as String? ?? existing.company,
                emails: emails,
                phones: phones,
                whatsapp: map['whatsapp'] as String? ?? existing.whatsapp,
                address: map['address'] as String? ?? existing.address,
                city: map['city'] as String? ?? existing.city,
                postalCode: map['postal_code'] as String? ?? existing.postalCode,
                country: map['country'] as String? ?? existing.country,
                notes: map['notes'] as String? ?? existing.notes,
                tags: tags,
                status: map['status'] as String? ?? existing.status,
                updatedAt: cloudUpdated,
              ),
            );
          } else if (existing.updatedAt.isAfter(cloudUpdated) && fieldsDiffer) {
            // Local is ahead of cloud with divergent fields - surface for Keep/Take UI.
            try {
              await ref.read(cloudCrmConflictsRepositoryProvider).reportConflict(
                    entityType: 'customer',
                    entityId: map['id'] as String?,
                    localId: localId,
                    localSnapshot: {
                      'contact_person': existing.contactPerson,
                      'company': existing.company,
                      'updated_at': existing.updatedAt.toUtc().toIso8601String(),
                    },
                    cloudSnapshot: {
                      'contact_person': cloudPerson,
                      'company': cloudCompany,
                      'updated_at': cloudUpdated.toUtc().toIso8601String(),
                    },
                  );
            } catch (e) {
              debugPrint('crm conflict report: $e');
            }
          }
          continue;
        }
      }

      // Insert cloud-only row into SQLite, then stamp local_id back to cloud.
      final newId = await db.insertCustomer(
        CustomersCompanion.insert(
          ownerUserId: ownerUserId,
          contactPerson: map['contact_person'] as String? ?? 'Client',
          company: Value(map['company'] as String? ?? ''),
          emails: Value(emails),
          phones: Value(phones),
          whatsapp: Value(map['whatsapp'] as String? ?? ''),
          address: Value(map['address'] as String? ?? ''),
          city: Value(map['city'] as String? ?? ''),
          postalCode: Value(map['postal_code'] as String? ?? ''),
          country: Value(map['country'] as String? ?? ''),
          notes: Value(map['notes'] as String? ?? ''),
          tags: Value(tags),
          status: Value(map['status'] as String? ?? 'active'),
        ),
      );
      final cloudId = map['id'] as String?;
      if (cloudId != null) {
        try {
          await _db.from('crm_customers').update({'local_id': newId}).eq('id', cloudId);
        } catch (e) {
          debugPrint('stamp crm_customers local_id: $e');
        }
      }
    }
  }

  Future<void> pullProjects({required int ownerUserId}) async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) return;
    final db = ref.read(databaseProvider);
    final rows = await _db.from('crm_projects').select().eq('owner_uid', uid);
    for (final raw in rows as List) {
      final map = Map<String, dynamic>.from(raw as Map);
      final localId = (map['local_id'] as num?)?.toInt();
      final localCustomerId = (map['local_customer_id'] as num?)?.toInt();
      var customerId = localCustomerId ?? 0;
      if (customerId <= 0) {
        final cloudCustomerId = map['customer_id'] as String?;
        if (cloudCustomerId != null) {
          try {
            final c = await _db
                .from('crm_customers')
                .select('local_id')
                .eq('id', cloudCustomerId)
                .maybeSingle();
            customerId = (c?['local_id'] as num?)?.toInt() ?? 0;
          } catch (_) {}
        }
      }
      if (customerId <= 0) continue;
      final cloudUpdated =
          DateTime.tryParse(map['updated_at'] as String? ?? '')?.toLocal() ?? DateTime.now();
      final start = DateTime.tryParse(map['start_date'] as String? ?? '');
      final deadline = DateTime.tryParse(map['deadline'] as String? ?? '');

      if (localId != null && localId > 0) {
        final existing = await db.getProjectForUser(ownerUserId, localId);
        if (existing != null) {
          if (cloudUpdated.isAfter(existing.updatedAt)) {
            await db.updateProject(
              existing.copyWith(
                name: map['name'] as String? ?? existing.name,
                customerId: customerId,
                description: map['description'] as String? ?? existing.description,
                budget: (map['budget'] as num?)?.toDouble() ?? existing.budget,
                currency: map['currency'] as String? ?? existing.currency,
                status: map['status'] as String? ?? existing.status,
                priority: map['priority'] as String? ?? existing.priority,
                startDate: Value(start?.toLocal() ?? existing.startDate),
                deadline: Value(deadline?.toLocal() ?? existing.deadline),
                updatedAt: cloudUpdated,
              ),
            );
          }
          continue;
        }
      }

      final newId = await db.insertProject(
        ProjectsCompanion.insert(
          ownerUserId: ownerUserId,
          customerId: customerId,
          name: map['name'] as String? ?? 'Project',
          description: Value(map['description'] as String? ?? ''),
          budget: Value((map['budget'] as num?)?.toDouble() ?? 0),
          currency: Value(map['currency'] as String? ?? 'USD'),
          status: Value(map['status'] as String? ?? 'not_started'),
          priority: Value(map['priority'] as String? ?? 'medium'),
          startDate: Value(start?.toLocal()),
          deadline: Value(deadline?.toLocal()),
        ),
      );
      final cloudId = map['id'] as String?;
      if (cloudId != null) {
        try {
          await _db.from('crm_projects').update({'local_id': newId}).eq('id', cloudId);
        } catch (_) {}
      }
    }
  }

  Future<void> pullInvoices({required int ownerUserId}) async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) return;
    final db = ref.read(databaseProvider);
    final rows = await _db.from('crm_invoices').select().eq('owner_uid', uid);
    for (final raw in rows as List) {
      final map = Map<String, dynamic>.from(raw as Map);
      final localId = (map['local_id'] as num?)?.toInt();
      var customerId = (map['local_customer_id'] as num?)?.toInt() ?? 0;
      if (customerId <= 0) {
        final cloudCustomerId = map['customer_id'] as String?;
        if (cloudCustomerId != null) {
          try {
            final c = await _db
                .from('crm_customers')
                .select('local_id')
                .eq('id', cloudCustomerId)
                .maybeSingle();
            customerId = (c?['local_id'] as num?)?.toInt() ?? 0;
          } catch (_) {}
        }
      }
      if (customerId <= 0) continue;
      int? projectId = (map['local_project_id'] as num?)?.toInt();
      if (projectId == null || projectId <= 0) {
        final cloudProjectId = map['project_id'] as String?;
        if (cloudProjectId != null) {
          try {
            final p = await _db
                .from('crm_projects')
                .select('local_id')
                .eq('id', cloudProjectId)
                .maybeSingle();
            projectId = (p?['local_id'] as num?)?.toInt();
          } catch (_) {}
        }
      }
      final cloudUpdated =
          DateTime.tryParse(map['updated_at'] as String? ?? '')?.toLocal() ?? DateTime.now();
      final due = DateTime.tryParse(map['due_date'] as String? ?? '');
      final lineItemsJson = jsonEncode(map['line_items'] ?? []);

      if (localId != null && localId > 0) {
        final existing = await db.getInvoiceForUser(ownerUserId, localId);
        if (existing != null) {
          if (cloudUpdated.isAfter(existing.updatedAt)) {
            await db.updateInvoice(
              existing.copyWith(
                invoiceNumber: map['invoice_number'] as String? ?? existing.invoiceNumber,
                customerId: customerId,
                projectId: Value(projectId),
                status: map['status'] as String? ?? existing.status,
                subtotal: (map['subtotal'] as num?)?.toDouble() ?? existing.subtotal,
                taxRate: (map['tax_rate'] as num?)?.toDouble() ?? existing.taxRate,
                discount: (map['discount'] as num?)?.toDouble() ?? existing.discount,
                total: (map['total'] as num?)?.toDouble() ?? existing.total,
                amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? existing.amountPaid,
                currency: map['currency'] as String? ?? existing.currency,
                lineItems: lineItemsJson,
                dueDate: Value(due?.toLocal() ?? existing.dueDate),
                updatedAt: cloudUpdated,
              ),
            );
          }
          continue;
        }
      }

      final newId = await db.insertInvoice(
        InvoicesCompanion.insert(
          ownerUserId: ownerUserId,
          invoiceNumber: map['invoice_number'] as String? ?? 'INV',
          customerId: customerId,
          projectId: Value(projectId),
          status: Value(map['status'] as String? ?? 'draft'),
          currency: Value(map['currency'] as String? ?? 'USD'),
          subtotal: Value((map['subtotal'] as num?)?.toDouble() ?? 0),
          taxRate: Value((map['tax_rate'] as num?)?.toDouble() ?? 0),
          discount: Value((map['discount'] as num?)?.toDouble() ?? 0),
          total: Value((map['total'] as num?)?.toDouble() ?? 0),
          amountPaid: Value((map['amount_paid'] as num?)?.toDouble() ?? 0),
          lineItems: Value(lineItemsJson),
          dueDate: Value(due?.toLocal()),
        ),
      );
      final cloudId = map['id'] as String?;
      if (cloudId != null) {
        try {
          await _db.from('crm_invoices').update({'local_id': newId}).eq('id', cloudId);
        } catch (_) {}
      }
    }
  }

  Future<void> _upsertByLocalId({
    required String table,
    required String uid,
    required int localId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final existing = await _db
          .from(table)
          .select('id')
          .eq('owner_uid', uid)
          .eq('local_id', localId)
          .maybeSingle();
      if (existing != null && existing['id'] != null) {
        await _db.from(table).update(payload).eq('id', existing['id'] as String);
      } else {
        await _db.from(table).insert(payload);
      }
    } catch (e) {
      debugPrint('$table upsert failed: $e');
      rethrow;
    }
  }

  List<String> _asStringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String && v.isNotEmpty) {
      try {
        final decoded = jsonDecode(v);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }
}
