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

  /// Resolves a stable host over DNS to decide whether the device is online.
  /// DNS resolution failure (no connection / resolver unavailable) maps to offline.
  static Future<bool> defaultReachabilityChecker() async {
    try {
      final result = await InternetAddress.lookup(
        'one.one.one.one',
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  NetworkStatus build() {
    final checker = ref.watch(reachabilityCheckerProvider);
    _startMonitoring(checker);
    ref.onDispose(() {
      _checkTimer?.cancel();
      _checkTimer = null;
    });
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
    try {
      final isOnline = await checker();
      if (!ref.mounted) return;
      state = isOnline ? NetworkStatus.online : NetworkStatus.offline;
    } catch (_) {
      if (!ref.mounted) return;
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
