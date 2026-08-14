import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports when the device's set of usable network transports changes.
///
/// Reconnection used to be driven purely by a blind backoff timer, which is
/// exactly the wrong shape for a phone: walking out of Wi-Fi range onto
/// cellular tears the socket down and brings a *working* network up moments
/// later, but the timer knows nothing about either event. It burns its early
/// attempts against the dead route and then sits out the rest of its capped
/// delay while the device is already back online. Listening for the handover
/// turns that dead time into an immediate retry.
abstract interface class NetworkMonitor {
  /// Emits on every transport change, carrying whether the device now has at
  /// least one usable transport. Does not emit the current value on listen.
  Stream<bool> get onChanged;
}

/// [NetworkMonitor] backed by `connectivity_plus`.
///
/// This reports *transport* availability (a Wi-Fi or cellular interface is up),
/// not reachability of the backend — a captive portal still reads as online.
/// That is the right trade-off here: the signal is only ever used to retry
/// sooner, and a retry that fails simply falls back to the normal backoff.
class ConnectivityNetworkMonitor implements NetworkMonitor {
  ConnectivityNetworkMonitor([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Stream<bool> get onChanged =>
      _connectivity.onConnectivityChanged.map(isOnline);

  /// True when [results] contains any transport other than
  /// [ConnectivityResult.none]. `connectivity_plus` reports a list because a
  /// device can hold several transports at once (e.g. Wi-Fi and VPN), and
  /// during a handover it briefly reports both the old and new ones.
  static bool isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}

/// A monitor that never emits, for platforms and tests with no connectivity
/// plugin behind them. Callers keep their normal backoff behavior.
class NoopNetworkMonitor implements NetworkMonitor {
  const NoopNetworkMonitor();

  @override
  Stream<bool> get onChanged => const Stream<bool>.empty();
}
