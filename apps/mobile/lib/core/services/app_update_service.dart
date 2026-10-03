import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/admin_config.dart';

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});

/// Play Store in-app updates. Prefer flexible update so local SQLite is never wiped.
class AppUpdateService {
  bool _checked = false;

  Future<void> checkForUpdate({bool forceStoreFallback = false}) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_checked && !forceStoreFallback) return;
    _checked = true;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;

      if (info.immediateUpdateAllowed) {
        // Immediate only when Play marks it critical; still keeps app data.
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
        return;
      }

      await openPlayStoreListing();
    } catch (e) {
      debugPrint('In-app update check failed: $e');
      if (forceStoreFallback) {
        await openPlayStoreListing();
      }
    }
  }

  Future<void> openPlayStoreListing() async {
    final uri = Uri.parse(kAppStoreUrl.isNotEmpty ? kAppStoreUrl : kProjectUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
