import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../routing/app_router.dart';

/// Routes notification taps (local / FCM payload) into the correct screen.
class NotificationDeepLink {
  /// Payload formats:
  /// - `kind` only: invoice|message|contract|team_invite|quote|payment|task|project
  /// - `kind:id` e.g. `invoice:42`, `task:7`
  /// - `route:/path`
  static void open(String? payload, {bool isClient = false}) {
    if (payload == null || payload.isEmpty) return;
    try {
      final route = resolveRoute(payload, isClient: isClient);
      if (route == null) return;
      appRouter.go(route);
    } catch (e) {
      debugPrint('Notification deep link failed: $e');
    }
  }

  static String? resolveRoute(String payload, {bool isClient = false}) {
    if (payload.startsWith('route:')) {
      return payload.substring(6);
    }

    String kind = payload;
    String? id;
    if (payload.contains(':')) {
      final parts = payload.split(':');
      kind = parts.first;
      id = parts.length > 1 ? parts.sublist(1).join(':') : null;
    }

    switch (kind) {
      case 'message':
      case 'invite':
        return isClient ? '/client-messages' : '/freelancer-messages';
      case 'invoice':
      case 'payment':
        if (id != null && id.isNotEmpty && !isClient) return '/invoices/$id/edit';
        return isClient ? '/client-invoices' : '/invoices';
      case 'quote':
        return isClient ? '/client-quotes' : '/quotes';
      case 'contract':
        return isClient ? '/client-contracts' : '/contracts';
      case 'team':
      case 'team_invite':
        return '/team-invites';
      case 'task':
        if (id != null && id.isNotEmpty && !isClient) return '/tasks/$id/edit';
        return isClient ? '/client-tasks' : '/tasks';
      case 'project':
      case 'milestone':
        return isClient ? '/client-portal' : '/projects';
      case 'review':
        return '/reviews';
      default:
        return '/notifications';
    }
  }
}

/// Convenience when GoRouter context is available.
void openNotificationPayload(GoRouter router, String? payload, {bool isClient = false}) {
  final route = NotificationDeepLink.resolveRoute(payload ?? '', isClient: isClient);
  if (route != null) router.go(route);
}
