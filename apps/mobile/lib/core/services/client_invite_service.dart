import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/database_provider.dart';
import '../auth/auth_service.dart';
import '../cloud/cloud_message_repository.dart';
import '../cloud/cloud_notification_repository.dart';
import '../cloud/supabase_sync_service.dart';
import 'clivora_email_service.dart';

final clientInviteServiceProvider = Provider<ClientInviteService>((ref) {
  return ClientInviteService(ref);
});

/// Invites a client by email, cloud message + notification when they have an account.
class ClientInviteService {
  ClientInviteService(this.ref);

  final Ref ref;

  Future<void> inviteClient({
    required Customer customer,
    required String clientEmail,
  }) async {
    final freelancer = ref.read(authStateProvider).valueOrNull;
    if (freelancer == null) return;

    final profile = await ref.read(databaseProvider).watchBusinessProfileForUser(freelancer.id).first;
    final businessName = profile.businessName.isNotEmpty ? profile.businessName : profile.ownerName;
    final email = clientEmail.trim().toLowerCase();
    if (email.isEmpty) return;

    final subject = 'You\'re invited to CLIVORA by $businessName';
    final body =
        'Hi ${customer.contactPerson},\n\n'
        '$businessName has added you as a client on CLIVORA. '
        'Download the app, sign up as a Client with this email ($email), '
        'and you\'ll see shared projects, messages, and invoices in real time.\n\n'
        'Welcome aboard!';

    final existingClient = await ref.read(databaseProvider).getUserByEmail(email);

    await ref.read(cloudMessageRepositoryProvider).sendHybrid(
          fromUser: freelancer,
          toEmail: email,
          subject: subject,
          body: body,
          localToUserId: existingClient?.id,
        );

    final toUid = await ref.read(supabaseSyncServiceProvider).uidForEmail(email);
    if (toUid != null) {
      await ref.read(cloudNotificationRepositoryProvider).sendToUid(
            toUid: toUid,
            title: 'CLIVORA invitation',
            body: '$businessName invited you as a client. Open Messages to read more.',
            kind: 'invite',
          );
    }

    // Optional external email, in-app message is the primary delivery path.
    final emailErr = await ref.read(clivoraEmailServiceProvider).sendClientInviteEmail(
          to: email,
          freelancerName: businessName,
          clientName: customer.contactPerson,
        );
    if (emailErr != null) {
      debugPrint('Client invite email skipped (in-app sent): $emailErr');
    }
  }
}
