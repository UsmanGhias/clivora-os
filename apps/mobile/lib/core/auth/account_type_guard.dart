import '../../data/database/database.dart';
import '../auth/user_roles.dart';
import '../constants/admin_config.dart';

/// One email = one role. Freelancers and clients cannot share an account.
class AccountTypeGuard {
  static String? validateSignUp({
    required String email,
    required String requestedType,
    User? existingLocal,
  }) {
    final normalized = email.trim().toLowerCase();
    if (kAdminEmails.contains(normalized)) return null;

    if (existingLocal != null) {
      return 'An account with this email already exists. Sign in instead.';
    }

    if (requestedType != kAccountFreelancer && requestedType != kAccountClient) {
      return 'Choose Freelancer or Client.';
    }
    return null;
  }

  static String? validateSignInRole({
    required User user,
    String? loginAsType,
  }) {
    if (isAdminUser(user) || isGuestUser(user)) return null;
    if (loginAsType == null) return null;

    final wantsClient = loginAsType == kAccountClient;
    final isClient = isClientUser(user);
    if (wantsClient != isClient) {
      final role = accountTypeLabel(user);
      return 'This email is registered as $role. Sign in using the $role option.';
    }
    return null;
  }

  static String? validateGoogleExisting({
    required User user,
    String? loginAsType,
  }) => validateSignInRole(user: user, loginAsType: loginAsType);

  static String normalizedAccountType(String? type, {required String email}) {
    if (kAdminEmails.contains(email.trim().toLowerCase())) return kAccountAdmin;
    return type == kAccountClient ? kAccountClient : kAccountFreelancer;
  }
}
