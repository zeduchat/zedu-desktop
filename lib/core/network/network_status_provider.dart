import 'dart:async';
import 'dart:io';

import 'package:zedu/core/core.dart';

enum NetworkStatus { online, offline }

typedef ReachabilityChecker = Future<bool> Function();

/// Provides a reachability check strategy. Defaults to resolving DNS via `InternetAddress.lookup`.
final reachabilityCheckerProvider = Provider<ReachabilityChecker>((ref) {
  return NetworkStatusNotifier.defaultReachabilityChecker;
});

class NetworkStatusNotifier extends Notifier<NetworkStatus> {
  Timer? _checkTimer;

  /// Counts reachability checks, so only the latest one sets the status.
  int _checkGeneration = 0;

  /// Resolves a stable host over DNS to decide whether the device is online.
  /// DNS resolution failure (no connection / resolver unavailable) maps to offline.
  static Future<bool> defaultReachabilityChecker() async {
    try {
      final result = await InternetAddress.lookup('ziki.dev');
      return result.any((record) => record.address.isNotEmpty);
    } catch (_) {
      return false;
    }
  }

  @override
  NetworkStatus build() {
    ref.onDispose(() {
      _checkTimer?.cancel();
      _checkTimer = null;
    });
    _startMonitoring(ref.read(reachabilityCheckerProvider));
    return NetworkStatus.online;
  }

  void _startMonitoring(ReachabilityChecker checker) {
    _checkTimer?.cancel();
    _checkReachability(checker);
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkReachability(checker);
    });
  }

  Future<void> checkReachability([ReachabilityChecker? customChecker]) async {
    final ReachabilityChecker checker =
        customChecker ?? ref.read(reachabilityCheckerProvider);
    await _checkReachability(checker);
  }

  Future<void> _checkReachability(ReachabilityChecker checker) async {
    final generation = ++_checkGeneration;
    bool isLatest() => ref.mounted && generation == _checkGeneration;
    try {
      final isOnline = await checker();
      if (!isLatest()) return;
      state = isOnline ? NetworkStatus.online : NetworkStatus.offline;
    } catch (_) {
      if (!isLatest()) return;
      state = NetworkStatus.offline;
    }
  }

  void setOffline() {
    state = NetworkStatus.offline;
  }

  void setOnline() {
    state = NetworkStatus.online;
  }

  void toggle() {
    state = state == NetworkStatus.online
        ? NetworkStatus.offline
        : NetworkStatus.online;
  }
}

final networkStatusProvider =
    NotifierProvider<NetworkStatusNotifier, NetworkStatus>(
      NetworkStatusNotifier.new,
    );
