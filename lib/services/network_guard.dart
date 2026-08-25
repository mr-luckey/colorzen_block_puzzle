import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Single connectivity signal for ads. Not a guarantee of internet.
class NetworkGuard {
  NetworkGuard({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _online = false;
  VoidCallback? _onOnline;
  Timer? _debounce;

  bool get isOnline => _online;

  Future<void> start({VoidCallback? onOnline}) async {
    _onOnline = onOnline;
    try {
      _online = _usable(await _connectivity.checkConnectivity());
    } catch (_) {
      _online = false;
    }
    await _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final next = _usable(results);
      if (next == _online) return;
      _online = next;
      if (!next) return;
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 2), () {
        if (_online) _onOnline?.call();
      });
    });
  }

  Future<void> dispose() async {
    _debounce?.cancel();
    await _subscription?.cancel();
  }

  static bool usableResults(List<ConnectivityResult> results) =>
      _usable(results);

  static bool _usable(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }
}
