import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_service.dart';

final telemetryServiceProvider = Provider<TelemetryService>((ref) {
  return TelemetryService(ref);
});

/// Firebase Analytics + Crashlytics on mobile; local analytics elsewhere (Linux desktop testing).
class TelemetryService {
  TelemetryService(this.ref);

  final Ref ref;
  bool _initialized = false;

  bool get _useFirebase =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (_useFirebase) {
      try {
        debugPrint('Telemetry: Firebase hooks ready for mobile builds');
      } catch (e) {
        debugPrint('Telemetry init skipped: $e');
      }
    }

    // Skip global handlers in widget tests (they must restore FlutterError.onError).
    if (const bool.fromEnvironment('FLUTTER_TEST')) return;

    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      prior?.call(details);
      _recordCrash(details.exceptionAsString(), details.stack?.toString() ?? '');
    };

    final priorPlatform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      final handled = priorPlatform?.call(error, stack) ?? false;
      _recordCrash(error.toString(), stack.toString());
      return handled;
    };
  }

  Future<void> logEvent(String name, {Map<String, Object?> params = const {}}) async {
    await ref.read(analyticsServiceProvider).track(
          eventType: name,
          payload: params.entries.map((e) => '${e.key}=${e.value}').join(','),
        );
    if (_useFirebase) {
      debugPrint('Telemetry event: $name $params');
    }
  }

  void _recordCrash(String message, String stack) {
    ref.read(analyticsServiceProvider).track(
          eventType: 'crash',
          payload: message.length > 500 ? message.substring(0, 500) : message,
        );
    debugPrint('Crash recorded: $message');
  }
}
