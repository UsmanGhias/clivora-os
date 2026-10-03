import '../../data/database/database.dart';
import 'user_roles.dart';

/// Post-login home route based on account type.
String homeRouteForUser(User? user) {
  if (user == null) return '/login';
  if (isSuperAdmin(user)) return '/admin-console';
  if (isClientUser(user)) return '/client-portal';
  return '/dashboard';
}

const _publicRoutes = {'/', '/login', '/signup', '/value-guidelines', '/onboarding'};

/// Routes only freelancers (and admin/guest preview as freelancer) may access.
const freelancerShellRoutes = {
  '/dashboard',
  '/customers',
  '/projects',
  '/invoices',
  '/more',
  '/menu',
  '/connect',
};

const freelancerExtraRoutes = {
  '/tasks',
  '/workspace-tasks',
  '/shared-tasks',
  '/expenses',
  '/notes',
  '/reports',
  '/calendar',
  '/analytics',
  '/backup',
  '/search',
  '/notifications',
  '/payments',
  '/profile',
  '/upgrade',
  '/ai-assistant',
  '/ai-suggestions',
  '/templates',
  '/contracts',
  '/automations',
  '/automation-builder',
  '/campaigns',
  '/crm-conflicts',
  '/sync-center',
  '/admin',
  '/admin-console',
  '/admin-ops',
  '/team',
  '/team-invites',
  '/storage',
  '/freelancer-messages',
  '/products',
  '/quotes',
  '/recurring-invoices',
  '/credits',
  '/payment-confirmations',
  '/security',
  '/notification-settings',
  '/reviews',
  '/referral',
};

/// Routes only clients may access.
const clientShellRoutes = {
  '/client-portal',
  '/client-messages',
  '/client-invoices',
  '/client-activity',
  '/client-contracts',
  '/client-link-freelancer',
  '/client-account',
  '/client-tasks',
  '/client-hub',
  '/client-quotes',
  '/client-payments',
  '/client-credits',
  '/client-recurring',
  '/client-files',
  '/client-milestones',
  '/notifications',
  '/profile',
  '/upgrade',
  '/referral',
  '/team-invites',
  '/connect',
};

bool isPublicRoute(String location) {
  if (_publicRoutes.contains(location)) return true;
  return false;
}

bool isFreelancerRoute(String location) {
  if (freelancerShellRoutes.any((r) => location == r || location.startsWith('$r/'))) {
    return true;
  }
  if (freelancerExtraRoutes.any((r) => location == r || location.startsWith('$r/'))) {
    return true;
  }
  if (location.startsWith('/customers/') ||
      location.startsWith('/projects/') ||
      location.startsWith('/invoices/') ||
      location.startsWith('/tasks/') ||
      location.startsWith('/expenses/') ||
      location.startsWith('/notes/')) {
    return true;
  }
  return false;
}

bool isClientRoute(String location) {
  return clientShellRoutes.any((r) => location == r || location.startsWith('$r/'));
}

bool isRouteAllowedForUser(User? user, String location) {
  if (user == null) return isPublicRoute(location);
  if (isPublicRoute(location)) return true;
  if (isAdminUser(user) &&
      (location == '/admin-console' || location == '/admin' || location == '/admin-ops')) {
    return true;
  }
  if (isClientUser(user)) return isClientRoute(location);
  return isFreelancerRoute(location);
}

/// GoRouter redirect based on auth session mirror.
String? authRedirect({required String location, required User? user, required bool loading}) {
  if (loading) return null;

  final path = Uri.parse(location).path;

  if (user == null) {
    if (isPublicRoute(path) || path.startsWith('/login') || path.startsWith('/signup')) {
      return null;
    }
    return '/login';
  }

  if (path == '/login' || path == '/signup') {
    return homeRouteForUser(user);
  }

  if (isGuestUser(user) && path == '/upgrade') {
    return '/login';
  }

  if ((path == '/admin-console' || path == '/admin' || path == '/admin-ops') && !isAdminUser(user)) {
    return homeRouteForUser(user);
  }

  // Shared routes (e.g. /notifications) are in both lists, do not redirect clients away.
  if (isClientUser(user) && isFreelancerRoute(path) && !isClientRoute(path)) {
    if (isAdminUser(user) &&
        (path == '/admin-console' || path == '/admin' || path == '/admin-ops')) {
      return null;
    }
    return '/client-portal';
  }

  if (isSuperAdmin(user) && path == '/dashboard') {
    return null;
  }

  // Shared routes (e.g. /profile, /upgrade, /connect) are in both lists
  // do not redirect freelancers away from them.
  if (!isClientUser(user) &&
      !isAdminUser(user) &&
      isClientRoute(path) &&
      !isFreelancerRoute(path)) {
    return '/dashboard';
  }

  return null;
}
