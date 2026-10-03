import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/user_roles.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import '../../features/client/client_contract_view.dart';
import '../utils/contract_content_helper.dart';
import '../auth/auth_service.dart';

final contractSyncServiceProvider = Provider<ContractSyncService>((ref) {
  return ContractSyncService(ref);
});

/// Applies client-signed contract messages to freelancer local records.
class ContractSyncService {
  ContractSyncService(this.ref);

  final Ref ref;

  Future<void> reconcileSignedContracts() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || isClientUser(user)) return;

    try {
      final mailbox = await ref.read(freelancerMailboxProvider.future);
      final db = ref.read(databaseProvider);
      final contracts = await db.watchContractsForUser(user.id).first;

      for (final msg in mailbox) {
        if (!msg.subject.startsWith(ClientContractView.signedPrefix)) continue;
        final title = msg.subject.replaceFirst(ClientContractView.signedPrefix, '').trim();
        if (title.isEmpty) continue;
        ContractContentHelper.decode(msg.body);

        for (final contract in contracts) {
          if (contract.title == title && contract.status != 'signed') {
            await db.updateContract(
              contract.copyWith(
                content: msg.body,
                status: 'signed',
                updatedAt: msg.createdAt.toLocal(),
              ),
            );
          }
        }
      }
      ref.invalidate(contractsProvider(null));
    } catch (e) {
      debugPrint('Contract sync failed: $e');
    }
  }
}
