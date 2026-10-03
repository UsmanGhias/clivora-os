import '../../data/database/database.dart';
import '../../routing/auth_refresh.dart';

/// Lightweight session mirror for [GoRouter] redirects (updated by [AuthNotifier]).
User? authSessionUser;
bool authSessionLoading = true;

void setAuthSession(User? user) {
  authSessionUser = user;
  authSessionLoading = false;
  notifyAuthChanged();
}

void setAuthSessionLoading(bool loading) {
  authSessionLoading = loading;
  notifyAuthChanged();
}

bool get isAuthenticated => authSessionUser != null;
