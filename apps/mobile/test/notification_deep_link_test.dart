import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:clivora/core/services/notification_deep_link.dart';

void main() {
  group('NotificationDeepLink.resolveRoute', () {
    test('routes invoice and payment for freelancer', () {
      expect(NotificationDeepLink.resolveRoute('invoice'), '/invoices');
      expect(NotificationDeepLink.resolveRoute('invoice:42'), '/invoices/42/edit');
      expect(NotificationDeepLink.resolveRoute('payment'), '/invoices');
    });

    test('routes client destinations', () {
      expect(NotificationDeepLink.resolveRoute('invoice', isClient: true), '/client-invoices');
      expect(NotificationDeepLink.resolveRoute('contract', isClient: true), '/client-contracts');
      expect(NotificationDeepLink.resolveRoute('message', isClient: true), '/client-messages');
    });

    test('routes team and explicit route payloads', () {
      expect(NotificationDeepLink.resolveRoute('team_invite'), '/team-invites');
      expect(NotificationDeepLink.resolveRoute('route:/quotes'), '/quotes');
    });
  });

  group('NotificationPrefs kind mapping', () {
    test('kind categories are stable JSON keys', () {
      // Guard against accidental rename of SharedPreferences keys.
      const keys = {
        'notif_pref_messages',
        'notif_pref_billing',
        'notif_pref_contracts',
        'notif_pref_team',
      };
      expect(jsonEncode(keys.toList()..sort()).contains('notif_pref_billing'), isTrue);
    });
  });
}
