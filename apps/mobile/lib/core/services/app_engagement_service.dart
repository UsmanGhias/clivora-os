import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/admin_config.dart';

final appEngagementServiceProvider = Provider<AppEngagementService>((ref) {
  return AppEngagementService(ref);
});

/// Share the app and point people at its store listing or source repository.
class AppEngagementService {
  AppEngagementService(this.ref);

  final Ref ref;

  static const playStorePackage = kAppPackageId;
  static String get playStoreUrl => kAppStoreUrl.isNotEmpty ? kAppStoreUrl : kProjectUrl;

  Future<void> shareApp({String? customMessage}) async {
    final message = customMessage ??
        'Try CLIVORA for clients, invoices, projects and chat in one app.\n$playStoreUrl';
    await SharePlus.instance.share(ShareParams(text: message, subject: 'CLIVORA'));
  }


  Future<void> openPlayStoreListing() async {
    final uri = Uri.parse(playStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Opens Play Store review page (same listing; users tap Reviews).
  Future<void> rateApp() async {
    final marketUri = Uri.parse('market://details?id=$playStorePackage');
    final webUri = Uri.parse(playStoreUrl);
    if (await canLaunchUrl(marketUri)) {
      await launchUrl(marketUri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<bool> shouldPromptRating() async {
    return true;
  }

  Future<void> showRateDialog(BuildContext context) async {
    if (!context.mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.star_rounded, color: Colors.amber, size: 40),
        title: const Text('Enjoying CLIVORA?'),
        content: const Text(
          'A quick rating on Google Play helps us grow and keeps updates coming. '
          'It only takes a few seconds!',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rate now')),
        ],
      ),
    );
    if (go == true) await rateApp();
  }
}
