import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkState {
  final bool isOnline;
  final bool isChecking;
  final DateTime? lastChecked;
  final String? statusMessage;

  NetworkState({
    this.isOnline = true,
    this.isChecking = false,
    this.lastChecked,
    this.statusMessage,
  });

  NetworkState copyWith({
    bool? isOnline,
    bool? isChecking,
    DateTime? lastChecked,
    String? statusMessage,
  }) {
    return NetworkState(
      isOnline: isOnline ?? this.isOnline,
      isChecking: isChecking ?? this.isChecking,
      lastChecked: lastChecked ?? this.lastChecked,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class NetworkService {
  /// Test actual internet reachability by resolving a reliable DNS host or connecting to DNS socket
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('dns.google')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      try {
        // Backup secondary lookup test
        final result = await InternetAddress.lookup('one.one.one.one')
            .timeout(const Duration(seconds: 3));
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (e) {
        if (kDebugMode) debugPrint('Network check failed: $e');
        return false;
      }
    }
  }
}

class NetworkNotifier extends Notifier<NetworkState> {
  Timer? _pollingTimer;

  @override
  NetworkState build() {
    _startMonitoring();
    ref.onDispose(() {
      _pollingTimer?.cancel();
    });
    return NetworkState();
  }

  void _startMonitoring() {
    checkConnection();
    // Poll internet status periodically every 6 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      checkConnection();
    });
  }

  Future<bool> checkConnection() async {
    state = state.copyWith(isChecking: true);
    final bool online = await NetworkService.hasInternetConnection();
    final now = DateTime.now();

    final bool statusChanged = state.isOnline != online;

    state = state.copyWith(
      isOnline: online,
      isChecking: false,
      lastChecked: now,
      statusMessage: online
          ? 'Connected to Internet'
          : 'No Internet Connection. Application is running in Offline Mode.',
    );

    if (statusChanged && kDebugMode) {
      debugPrint('Network status changed! Online: $online');
    }

    return online;
  }
}

final networkNotifierProvider = NotifierProvider<NetworkNotifier, NetworkState>(NetworkNotifier.new);

final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(networkNotifierProvider).isOnline;
});
