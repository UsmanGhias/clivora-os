import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clivora/data/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('schema v18 creates sync_outbox_entries', () async {
    expect(db.schemaVersion, 18);
    final id = await db.insertSyncOutbox(
      SyncOutboxEntriesCompanion.insert(
        operationId: 'op-1',
        kind: 'crm_project',
        payloadJson: const Value('{"localId":1}'),
      ),
    );
    expect(id, greaterThan(0));
    final rows = await db.listActiveOutbox();
    expect(rows, hasLength(1));
    expect(rows.first.status, 'pending');
    expect(rows.first.operationId, 'op-1');
  });

  test('unknown kinds can be marked permanently_failed and retained', () async {
    final id = await db.insertSyncOutbox(
      SyncOutboxEntriesCompanion.insert(
        operationId: 'bad-1',
        kind: 'totally_unknown_kind',
      ),
    );
    final row = (await db.listActiveOutbox()).firstWhere((r) => r.id == id);
    await db.updateSyncOutbox(
      row.copyWith(
        status: 'permanently_failed',
        lastError: const Value('Unknown or unsupported operation'),
      ),
    );
    final failed = await db.listActiveOutbox();
    expect(failed.where((r) => r.status == 'permanently_failed'), isNotEmpty);
    expect(failed.any((r) => r.kind == 'totally_unknown_kind'), isTrue);
  });

  test('prefs-shaped payload migrates via insert companions', () async {
    final legacy = [
      {
        'kind': 'crm_customer',
        'payload': {'localId': 42},
        'retries': 2,
        'createdAt': DateTime.now().toIso8601String(),
        'operationId': 'legacy-op',
      },
    ];
    // Simulate migration insert path used by SyncOutboxService.ensureMigrated
    for (final e in legacy) {
      await db.insertSyncOutbox(
        SyncOutboxEntriesCompanion.insert(
          operationId: e['operationId'] as String,
          kind: e['kind'] as String,
          payloadJson: Value(jsonEncode(e['payload'])),
          retries: Value(e['retries'] as int),
        ),
      );
    }
    final rows = await db.listActiveOutbox();
    expect(rows.single.kind, 'crm_customer');
    expect(jsonDecode(rows.single.payloadJson)['localId'], 42);
  });

  test('conflict rows are retained until deleted', () async {
    await db.insertSyncConflict(
      SyncConflictEntriesCompanion.insert(
        entityType: 'project',
        localId: 9,
        localStatus: const Value('in_progress'),
        cloudStatus: const Value('completed'),
      ),
    );
    expect(await db.listSyncConflicts(), hasLength(1));
    await db.deleteSyncConflict(entityType: 'project', localId: 9);
    expect(await db.listSyncConflicts(), isEmpty);
  });
}
