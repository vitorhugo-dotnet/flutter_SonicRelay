import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

import '../diagnostics/sonic_log.dart';
import 'ice_servers_api.dart';
import 'relay_modes.dart';
import 'rtc_ice_server_config.dart';

/// Resolves the ICE server configuration used for a WebRTC negotiation,
/// caching the backend result until shortly before its TURN credentials
/// expire. It never throws: on failure it returns the last good
/// configuration. If there is no cache yet, it falls back to the public-STUN
/// [RtcIceServerConfig.defaults] only when [allowGoogleStunDevFallback] is
/// true (debug builds by default) — production builds instead get an empty
/// ICE server list rather than silently depending on Google's public STUN
/// server, per the "no production code path relies only on Google STUN"
/// requirement.
class IceServersRepository {
  IceServersRepository({
    required IceServersApi api,
    required String Function() relayMode,
    required String? Function() coturnOverride,
    DateTime Function()? now,
    bool? allowGoogleStunDevFallback,
  }) : _api = api,
       _relayMode = relayMode,
       _coturnOverride = coturnOverride,
       _now = now ?? DateTime.now,
       _allowGoogleStunDevFallback =
           allowGoogleStunDevFallback ?? kDebugMode;

  final IceServersApi _api;
  final String Function() _relayMode;
  final String? Function() _coturnOverride;
  final DateTime Function() _now;
  final bool _allowGoogleStunDevFallback;

  RtcIceServerConfig? _cached;
  DateTime _expiresAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<RtcIceServerConfig> resolve() async {
    final cached = _cached;
    if (cached != null && _now().isBefore(_expiresAt)) {
      return cached;
    }
    try {
      final result = await _api.fetch();
      // Refresh a minute before the credentials lapse so a renegotiation never
      // starts with a stale TURN username.
      final marginSeconds = result.expiresAt.difference(_now()).inSeconds - 60;
      _expiresAt = _now().add(
        Duration(seconds: marginSeconds < 30 ? 30 : marginSeconds),
      );
      _cached = _applyPreferences(result.config);
      return _cached!;
    } on DioException catch (error) {
      sonicLog('WebRTC', 'ice-servers fetch failed: ${error.message}');
      return _fallback();
    } catch (error) {
      sonicLog('WebRTC', 'ice-servers parse failed: $error');
      return _fallback();
    }
  }

  RtcIceServerConfig _fallback() {
    final cached = _cached;
    if (cached != null) return cached;
    if (_allowGoogleStunDevFallback) return RtcIceServerConfig.defaults();
    return const RtcIceServerConfig([]);
  }

  /// Applies this device's local relay preferences to the backend's list. `disableFallback`
  /// is enforced here rather than server-side because the preference is per-device: a backend
  /// that withheld TURN would impose one device's choice on every other device it serves.
  /// The override swaps only the TURN urls — STUN entries carry no credential, and the
  /// server-issued username/credential are preserved because they are what authenticates.
  RtcIceServerConfig _applyPreferences(RtcIceServerConfig config) {
    final override = _coturnOverride();
    final disableFallback = _relayMode() == RelayModes.disableFallback;
    final servers = <RtcIceServer>[];
    for (final server in config.iceServers) {
      final isTurn =
          server.urls.first.toLowerCase().startsWith('turn:') ||
          server.urls.first.toLowerCase().startsWith('turns:');
      if (isTurn && disableFallback) continue;
      servers.add(
        isTurn && override != null
            ? RtcIceServer(
                urls: [override],
                username: server.username,
                credential: server.credential,
              )
            : server,
      );
    }
    // forceRelay is preserved rather than defaulted: it is a separate field on the config
    // (applied as iceTransportPolicy) that the receiver service sets, not part of the list.
    return RtcIceServerConfig(servers, forceRelay: config.forceRelay);
  }
}
