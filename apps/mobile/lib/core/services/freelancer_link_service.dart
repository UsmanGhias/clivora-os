import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_service.dart';
import '../auth/user_roles.dart';
import '../cloud/cloud_message_repository.dart';
import '../cloud/cloud_notification_repository.dart';
import '../cloud/supabase_auth_helper.dart';
import '../cloud/supabase_sync_service.dart';

final freelancerLinkServiceProvider = Provider<FreelancerLinkService>((ref) {
  return FreelancerLinkService(ref);
});

/// Client invites / links a freelancer by email (two-way onboarding).
class FreelancerLinkService {
  FreelancerLinkService(this.ref);

  final Ref ref;

  Future<String?> linkFreelancerByEmail(String freelancerEmail) async {
    final client = ref.read(authStateProvider).valueOrNull;
    if (client == null || !isClientUser(client)) return 'Sign in as a client first';

    final email = freelancerEmail.trim().toLowerCase();
    if (!email.contains('@')) return 'Enter a valid freelancer email';

    if (email == client.email.toLowerCase()) {
      return 'Enter your freelancer\'s email, not your own';
    }

    final clientUid = SupabaseAuthHelper.currentUid;
    if (clientUid == null || clientUid.isEmpty) {
      return 'Sign in with Google or email (not guest) to connect with a freelancer';
    }

    final freelancerUid = await ref.read(supabaseSyncServiceProvider).uidForEmail(email);

    final subject = '[Link Request] ${client.name} wants to connect';
    final body =
        'Hi,\n\n'
        '${client.name} (${client.email}) would like to work with you on CLIVORA.\n\n'
        'Please share a project with their email so they can view progress, invoices, and messages.\n\n'
        'Open CLIVORA → Clients → share a project using: ${client.email}';

    try {
      await ref.read(cloudMessageRepositoryProvider).sendMessage(
            fromUid: clientUid,
            fromEmail: client.email,
            toEmail: email,
            toUid: freelancerUid,
            subject: subject,
            body: body,
          );
    } catch (e) {
      return 'Could not send link request: $e';
    }

    if (freelancerUid != null) {
      await ref.read(cloudNotificationRepositoryProvider).sendToUid(
            toUid: freelancerUid,
            title: 'New client connection request',
            body: '${client.name} wants to link with you on CLIVORA',
            kind: 'invite',
          );
    }

    return null;
  }
}
