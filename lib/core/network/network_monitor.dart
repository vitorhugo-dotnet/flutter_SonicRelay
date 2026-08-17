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

  /// Whether the device has a usable transport right now.
  ///
  /// [onChanged] only reports transitions, so a caller that needs to decide
  /// *before* the next handover — such as the reconnect loop deciding whether an
  /// attempt is worth spending budget on — has nothing to read without this.
  /// Defaults to optimistic on every implementation: a monitor that cannot tell
  /// must not be the reason a reconnect never happens.
  bool get isOnline;
}

/// [NetworkMonitor] backed by `connectivity_plus`.
///
/// This reports *transport* availability (a Wi-Fi or cellular interface is up),
/// not reachability of the backend — a captive portal still reads as online.
/// That is the right trade-off here: the signal is only ever used to retry
/// sooner or to hold off a retry that could not succeed, and a wrong answer
/// costs at most one wasted attempt or one delayed one.
class ConnectivityNetworkMonitor implements NetworkMonitor {
  ConnectivityNetworkMonitor([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity() {
    _changes = _connectivity.onConnectivityChanged
        .map(hasUsableTransport)
        .asBroadcastStream();
    _subscription = _changes.listen((online) => _isOnline = online);
    // Seed from the current transports. The stream only reports transitions, so
    // a device that is already offline when the app starts would otherwise read
    // as online until its first handover — and the very first reconnect would
    // spend its budget against a route that was never there.
    unawaited(_seedFromCurrentTransports());
  }

  final Connectivity _connectivity;
  late final Stream<bool> _changes;
  late final StreamSubscription<bool> _subscription;
  bool _isOnline = true;

  @override
  Stream<bool> get onChanged => _changes;

  @override
  bool get isOnline => _isOnline;

  Future<void> _seedFromCurrentTransports() async {
    try {
      _isOnline = hasUsableTransport(await _connectivity.checkConnectivity());
    } catch (_) {
      // A probe that fails must never make the device look offline: that would
      // park recovery on a fact we do not actually have, and the optimistic
      // default costs at most one attempt that would have failed anyway.
    }
  }

  Future<void> dispose() => _subscription.cancel();

  /// True when [results] contains any transport other than
  /// [ConnectivityResult.none]. `connectivity_plus` reports a list because a
  /// device can hold several transports at once (e.g. Wi-Fi and VPN), and
  /// during a handover it briefly reports both the old and new ones.
  static bool hasUsableTransport(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}

/// A monitor that never emits, for platforms and tests with no connectivity
/// plugin behind them. Callers keep their normal backoff behavior.
class NoopNetworkMonitor implements NetworkMonitor {
  const NoopNetworkMonitor();

  @override
  Stream<bool> get onChanged => const Stream<bool>.empty();

  @override
  bool get isOnline => true;
}
