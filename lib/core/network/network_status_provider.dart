import 'dart:async';

import 'package:zedu/core/core.dart';

enum NetworkStatus { online, offline }

typedef ReachabilityChecker = Future<bool> Function();

/// Provides a reachability check strategy. Defaults to asking the app's API
/// host ([AppConfig.apiBaseUrl]) for any HTTP response.
final reachabilityCheckerProvider = Provider<ReachabilityChecker>((ref) {
  return () => NetworkStatusNotifier.apiReachabilityChecker(
    locator<AppConfig>().apiBaseUrl,
  );
});

class NetworkStatusNotifier extends Notifier<NetworkStatus> {
  Timer? _checkTimer;

  /// A plain client with short timeouts, so the check sends no session token
  /// and an unreachable host is reported quickly.
  static final Dio _reachabilityClient = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      validateStatus: (_) => true,
    ),
  );

  /// Sends `HEAD` to [baseUrl], the app's API host. Any HTTP response, even
  /// an error status, means the device is online; a connection error or a
  /// timeout means it is offline.
  static Future<bool> apiReachabilityChecker(
    String baseUrl, {
    Dio? client,
  }) async {
    try {
      await (client ?? _reachabilityClient).head<void>(
        baseUrl,
        options: Options(validateStatus: (_) => true),
      );
      return true;
    } on DioException catch (error) {
      return error.response != null;
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
