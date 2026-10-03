import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/supabase_auth_helper.dart';
import '../constants/plan_limits.dart';
import 'email_quota_service.dart';

/// Sends special-purpose emails via Supabase Edge Function.
final clivoraEmailServiceProvider = Provider<ClivoraEmailService>((ref) {
  return ClivoraEmailService(ref);
});

class ClivoraEmailService {
  ClivoraEmailService(this.ref);

  final Ref ref;

  Future<String?> sendSpecialEmail({
    required String to,
    required String subject,
    required String htmlBody,
    required ClivoraEmailPurpose purpose,
    bool countTowardQuota = true,
    Map<String, dynamic>? extraFields,
  }) async {
    if (countTowardQuota && purpose != ClivoraEmailPurpose.passwordReset) {
      if (!await ref.read(emailQuotaServiceProvider).canSendEmail()) {
        return 'Free plan limit: ${PlanLimits.freeMaxEmailsPerMonth} emails/month. Upgrade to Pro for more.';
      }
    }

    try {
      final response = await SupabaseAuthHelper.client.functions.invoke(
        'send-clivora-email',
        body: {
          'to': to.trim().toLowerCase(),
          'subject': subject,
          'purpose': purpose.name,
          if (htmlBody.isNotEmpty) 'html': htmlBody,
          ...?extraFields,
        },
      );
      if (response.status != 200) {
        final data = response.data;
        final detail = data is Map ? '${data['error'] ?? response.status}' : 'Email failed (${response.status})';
        return detail;
      }
      if (countTowardQuota && purpose != ClivoraEmailPurpose.passwordReset) {
        await ref.read(emailQuotaServiceProvider).recordSent();
      }
      return null;
    } on FunctionException catch (e) {
      debugPrint('Clivora email FunctionException: ${e.details}');
      final details = e.details;
      if (details is Map && details['error'] != null) {
        return _friendlyEmailError('${details['error']}');
      }
      return _friendlyEmailError('Email service error (${e.status})');
    } catch (e) {
      debugPrint('Clivora email error: $e');
      return 'Email delivery unavailable. Your in-app message was still sent.';
    }
  }

  Future<String?> sendPasswordResetNotice(String email) {
    return sendSpecialEmail(
      to: email,
      subject: 'Reset your CLIVORA password',
      htmlBody: '',
      purpose: ClivoraEmailPurpose.passwordReset,
      countTowardQuota: false,
    );
  }

  Future<String?> sendClientInviteEmail({
    required String to,
    required String freelancerName,
    required String clientName,
  }) {
    return sendSpecialEmail(
      to: to,
      subject: '$freelancerName invited you to CLIVORA',
      htmlBody: '',
      purpose: ClivoraEmailPurpose.clientInvite,
      extraFields: {
        'freelancerName': freelancerName,
        'clientName': clientName,
      },
    );
  }

  Future<String?> sendAdminNotice({
    required String to,
    required String subject,
    required String message,
  }) {
    return sendSpecialEmail(
      to: to,
      subject: subject,
      htmlBody: message,
      purpose: ClivoraEmailPurpose.adminNotice,
      extraFields: {'adminMessage': message},
    );
  }

  Future<String?> sendTeamInviteEmail({
    required String to,
    required String ownerName,
    required String inviteeName,
    required String role,
    String projectName = '',
  }) {
    return sendSpecialEmail(
      to: to,
      subject: '$ownerName invited you to their CLIVORA team',
      htmlBody: '',
      purpose: ClivoraEmailPurpose.teamInvite,
      extraFields: {
        'ownerName': ownerName,
        'inviteeName': inviteeName,
        'role': role,
        if (projectName.isNotEmpty) 'projectName': projectName,
      },
    );
  }

  Future<String?> sendTaskCompletedEmail({
    required String to,
    required String clientName,
    required String taskTitle,
    required String projectName,
  }) {
    return sendSpecialEmail(
      to: to,
      subject: 'Task completed: $taskTitle',
      htmlBody: '',
      purpose: ClivoraEmailPurpose.taskCompleted,
      extraFields: {
        'clientName': clientName,
        'taskTitle': taskTitle,
        'projectName': projectName,
      },
    );
  }

  Future<String?> sendWelcomeEmail({
    required String to,
    required String userName,
    required String accountType,
  }) {
    return sendSpecialEmail(
      to: to,
      subject: 'Welcome to CLIVORA',
      htmlBody: '',
      purpose: ClivoraEmailPurpose.welcome,
      extraFields: {
        'userName': userName,
        'accountType': accountType,
      },
    );
  }
}

String _friendlyEmailError(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('smtp') || lower.contains('not configured')) {
    return 'External email temporarily unavailable. In-app invite was delivered.';
  }
  if (lower.contains('monthly email limit')) {
    return raw;
  }
  return 'Could not send external email. In-app invite was delivered.';
}

enum ClivoraEmailPurpose {
  passwordReset,
  adminNotice,
  clientInvite,
  teamInvite,
  taskCompleted,
  welcome,
}

extension on ClivoraEmailPurpose {
  String get name {
    switch (this) {
      case ClivoraEmailPurpose.passwordReset:
        return 'password_reset';
      case ClivoraEmailPurpose.adminNotice:
        return 'admin_notice';
      case ClivoraEmailPurpose.clientInvite:
        return 'client_invite';
      case ClivoraEmailPurpose.teamInvite:
        return 'team_invite';
      case ClivoraEmailPurpose.taskCompleted:
        return 'task_completed';
      case ClivoraEmailPurpose.welcome:
        return 'welcome';
    }
  }
}
