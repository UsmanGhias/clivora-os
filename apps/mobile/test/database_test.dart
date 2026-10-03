import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clivora/data/database/database.dart';
import 'package:clivora/data/database/user_scoped_queries.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppDatabase', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('inserts and reads customer', () async {
      final id = await db.insertCustomer(
        CustomersCompanion.insert(ownerUserId: 1, contactPerson: 'Jane Doe'),
      );
      final customer = await db.getCustomer(id);
      expect(customer?.contactPerson, 'Jane Doe');
    });

    test('counts invoices this month', () async {
      await db.insertCustomer(CustomersCompanion.insert(ownerUserId: 1, contactPerson: 'Test'));
      final customers = await db.watchCustomersForUser(1).first;
      await db.insertInvoice(
        InvoicesCompanion.insert(
          ownerUserId: 1,
          invoiceNumber: 'INV-001',
          customerId: customers.first.id,
        ),
      );
      final count = await db.countInvoicesThisMonthForUser(1);
      expect(count, 1);
    });
  });
}
