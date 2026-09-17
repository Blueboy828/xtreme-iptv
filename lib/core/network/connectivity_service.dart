import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitors device connectivity.
///
/// On Fire TV / Android TV, connectivity_plus may report false
/// negatives. All methods fail OPEN (return true/connected) if
/// the check fails. This class is used only for the reconnection
/// stream — not for blocking requests.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  bool _wasConnected = true;

  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  /// Always returns true on Fire TV / Android TV.
  /// Fails open if the check throws.
  Future<bool> get isConnected async {
    try {
      final results = await _connectivity
          .checkConnectivity()
          .timeout(const Duration(seconds: 2));
      // On Fire TV, results might be [none] even when connected.
      // Only trust a definitive "none" when the list is exactly [none].
      if (results.length == 1 && results.contains(ConnectivityResult.none)) {
        // Could be a real offline state OR a Fire TV false negative.
        // Fail open — let Dio handle the actual network error.
        return true;
      }
      return true;
    } catch (_) {
      return true; // Always fail open.
    }
  }

  Stream<bool> get onReconnect => onConnectivityChanged
      .map((results) => !results.contains(ConnectivityResult.none))
      .where((isOnline) {
        final wasConnected = _wasConnected;
        _wasConnected = isOnline;
        return isOnline && !wasConnected;
      });

  Future<bool> get isReconnecting async {
    final connected = await isConnected;
    final wasConnected = _wasConnected;
    _wasConnected = connected;
    return connected && !wasConnected;
  }
}
