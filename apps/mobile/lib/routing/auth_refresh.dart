import 'package:flutter/foundation.dart';

/// Notifies [GoRouter] to re-run redirects when auth changes.
final authRefreshListenable = ValueNotifier<int>(0);

void notifyAuthChanged() {
  authRefreshListenable.value++;
}
