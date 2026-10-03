import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/providers/app_providers.dart';

final analyticsExportServiceProvider = Provider<AnalyticsExportService>((ref) {
  return AnalyticsExportService(ref);
});

class AnalyticsExportService {
  AnalyticsExportService(this.ref);

  final Ref ref;

  Future<void> exportAndShare() async {
    final db = ref.read(databaseProvider);
    final users = await db.getAllUsers();
    final events = await db.getAllAnalytics();
    String subscriptionPlan = 'pro';
    try {
      final settings = await db.watchAppSettings().first.timeout(const Duration(seconds: 3));
      subscriptionPlan = settings.subscriptionPlan;
    } catch (_) {
      subscriptionPlan = 'pro';
    }

    final payload = {
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'CLIVORA',
      'version': '1.5.5',
      'subscriptionPlan': subscriptionPlan,
      'users': users
          .map((u) => {
                'id': u.id,
                'email': u.email,
                'name': u.name,
                'role': u.role,
                'createdAt': u.createdAt.toIso8601String(),
              })
          .toList(),
      'events': events
          .map((e) => {
                'id': e.id,
                'eventType': e.eventType,
                'userEmail': e.userEmail,
                'userName': e.userName,
                'plan': e.plan,
                'amount': e.amount,
                'payload': e.payload,
                'createdAt': e.createdAt.toIso8601String(),
              })
          .toList(),
      'summary': {
        'totalUsers': users.length,
        'signups': events.where((e) => e.eventType == 'signup').length,
        'proActivations': events.where((e) => e.eventType == 'pro_activate').length,
      },
    };

    final json = const JsonEncoder.withIndent('  ').convert(payload);
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '').split('.').first;
    final file = File('${dir.path}/clivora-admin-export-$stamp.json');
    await file.writeAsString(json);

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json', name: file.uri.pathSegments.last)],
          subject: 'CLIVORA Admin Export',
          text: 'CLIVORA analytics export (${users.length} users, ${events.length} events)',
        ),
      );
    } catch (_) {
      await SharePlus.instance.share(
        ShareParams(
          text: json,
          subject: 'CLIVORA Admin Export',
        ),
      );
    }
  }
}
