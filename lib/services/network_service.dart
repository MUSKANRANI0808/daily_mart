import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkService {
  NetworkService._private();
  static final NetworkService instance = NetworkService._private();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Global reactive notifier for internet connectivity state
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(true);

  bool _isChecking = false;

  /// Initialize continuous background connectivity monitoring
  Future<void> initialize() async {
    // Initial check
    await checkConnection();

    // Listen to network interface changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) async {
      final isNone = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      if (isNone) {
        isConnectedNotifier.value = false;
      } else {
        await checkConnection();
      }
    });

    // Heartbeat check every 5 seconds to catch silent disconnects (e.g. WiFi with no data)
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!isConnectedNotifier.value) {
        // If currently disconnected, check if connection is restored
        checkConnection();
      }
    });
  }

  /// Actively test real internet reachability
  Future<bool> checkConnection() async {
    if (_isChecking) return isConnectedNotifier.value;
    _isChecking = true;

    try {
      final results = await _connectivity.checkConnectivity();
      final isNone = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      if (isNone) {
        if (isConnectedNotifier.value != false) {
          isConnectedNotifier.value = false;
        }
        _isChecking = false;
        return false;
      }

      // Real DNS / Socket reachability probe
      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(milliseconds: 2500));
      final hasConnection = lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;

      if (isConnectedNotifier.value != hasConnection) {
        isConnectedNotifier.value = hasConnection;
      }
      _isChecking = false;
      return hasConnection;
    } catch (_) {
      // Fallback secondary probe in case google.com DNS is slow/blocked
      try {
        final secondaryLookup = await InternetAddress.lookup('cloudflare.com')
            .timeout(const Duration(milliseconds: 2500));
        final hasConnection = secondaryLookup.isNotEmpty && secondaryLookup[0].rawAddress.isNotEmpty;
        if (isConnectedNotifier.value != hasConnection) {
          isConnectedNotifier.value = hasConnection;
        }
        _isChecking = false;
        return hasConnection;
      } catch (_) {
        if (isConnectedNotifier.value != false) {
          isConnectedNotifier.value = false;
        }
        _isChecking = false;
        return false;
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
