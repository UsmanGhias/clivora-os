import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/user_roles.dart';
import '../cloud/supabase_auth_helper.dart';
import 'local_notification_service.dart';
import 'notification_deep_link.dart';
import 'notification_prefs_service.dart';

final fcmServiceProvider = Provider<FcmService>((ref) => FcmService(ref));

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolate, keep minimal; OS shows the notification tray entry.
  debugPrint('FCM background: ${message.messageId}');
}

/// Registers FCM tokens and routes notification taps to deep links.
class FcmService {
  FcmService(this.ref);
  final Ref ref;
  bool _ready = false;

  Future<void> initialize() async {
    if (_ready) return;
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      _ready = true;
      return;
    }
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        _onOpened(initial);
      }

      messaging.onTokenRefresh.listen(_upsertToken);
      final token = await messaging.getToken();
      if (token != null) await _upsertToken(token);
      _ready = true;
    } catch (e) {
      debugPrint('FCM init skipped: $e');
      _ready = true;
    }
  }

  Future<void> onUserSignedIn() async {
    await initialize();
    try {
      if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _upsertToken(token);
    } catch (e) {
      debugPrint('FCM token refresh failed: $e');
    }
  }

  Future<void> _upsertToken(String token) async {
    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null || uid.isEmpty) return;
    try {
      await SupabaseAuthHelper.client.from('device_tokens').upsert({
        'user_uid': uid,
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_uid,token');
    } catch (e) {
      debugPrint('device_tokens upsert failed: $e');
    }
  }

  Future<void> _onForeground(RemoteMessage message) async {
    final title = message.notification?.title ?? message.data['title'] ?? 'CLIVORA';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    final kind = message.data['kind']?.toString() ?? 'info';
    final entityId = message.data['entity_id']?.toString();
    if (!await ref.read(notificationPrefsServiceProvider).allowsKind(kind)) return;
    final payload = entityId != null && entityId.isNotEmpty ? '$kind:$entityId' : kind;
    await ref.read(localNotificationServiceProvider).show(
          title: title,
          body: body,
          payload: payload,
        );
  }

  void _onOpened(RemoteMessage message) {
    final kind = message.data['kind']?.toString() ?? 'info';
    final entityId = message.data['entity_id']?.toString();
    final payload = entityId != null && entityId.isNotEmpty ? '$kind:$entityId' : kind;
    final isClient = isClientUser(null); // refined by auth when available
    NotificationDeepLink.open(payload, isClient: isClient);
  }
}
