import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService(ref);
});

final isOnlineProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).onlineStream;
});

/// Monitors network status and triggers sync when connection returns.
class ConnectivityService {
  ConnectivityService(this.ref);

  final Ref ref;

  final _connectivity = Connectivity();
  bool _wasOffline = false;
  bool? _lastOnline;

  Stream<bool> get onlineStream async* {
    yield await isOnlineNow();
    await for (final results in _connectivity.onConnectivityChanged) {
      yield _isOnline(results);
    }
  }

  Future<bool> isOnlineNow() async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  void startListening(void Function(bool online) onChange) {
    _connectivity.onConnectivityChanged.listen((results) async {
      final online = _isOnline(results);
      if (_lastOnline == online) return;
      if (_wasOffline && online) {
        onChange(true);
      } else if (!online) {
        onChange(false);
      }
      _wasOffline = !online;
      _lastOnline = online;
    });
  }
}
