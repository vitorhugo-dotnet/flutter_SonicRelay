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
///
/// The cache holds the *raw* backend config. [_applyPreferences] (relay mode,
/// coturn override) runs on every call to [resolve], including cache hits and
/// the failure fallback — this repository is a process-lifetime singleton, so
/// a user can change either preference in Settings and rejoin a session
/// entirely within the ~1h TURN credential cache window. Applying preferences
/// only on fetch would silently serve the old behaviour in that case.
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

  // Raw backend config, unmodified by local preferences — those are applied
  // fresh on every resolve()/fallback() return, not baked in at fetch time.
  RtcIceServerConfig? _cachedRaw;
  DateTime _expiresAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<RtcIceServerConfig> resolve() async {
    final cached = _cachedRaw;
    if (cached != null && _now().isBefore(_expiresAt)) {
      return _applyPreferences(cached);
    }
    try {
      final result = await _api.fetch();
      // Refresh a minute before the credentials lapse so a renegotiation never
      // starts with a stale TURN username.
      final marginSeconds = result.expiresAt.difference(_now()).inSeconds - 60;
      _expiresAt = _now().add(
        Duration(seconds: marginSeconds < 30 ? 30 : marginSeconds),
      );
      _cachedRaw = result.config;
      return _applyPreferences(result.config);
    } on DioException catch (error) {
      sonicLog('WebRTC', 'ice-servers fetch failed: ${error.message}');
      return _fallback();
    } catch (error) {
      sonicLog('WebRTC', 'ice-servers parse failed: $error');
      return _fallback();
    }
  }

  RtcIceServerConfig _fallback() {
    final cached = _cachedRaw;
    // Preferences apply here too: a stale raw cache can still hold TURN
    // entries that disableFallback should drop, or a backend TURN url that
    // an override should replace, even though this call didn't fetch.
    if (cached != null) return _applyPreferences(cached);
    if (_allowGoogleStunDevFallback) {
      return _applyPreferences(RtcIceServerConfig.defaults());
    }
    return _applyPreferences(const RtcIceServerConfig([]));
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
    if (servers.isEmpty) {
      // No STUN and no TURN leaves the peer connection with host candidates
      // only, which cannot cross a NAT — so the negotiation that follows is
      // almost certainly doomed. Withholding the public-STUN fallback in
      // production is deliberate, but the resulting dead connection used to be
      // indistinguishable from any other ICE failure in the logs.
      sonicLog(
        'WebRTC',
        'resolved with no ICE servers — host candidates only, '
            'so this negotiation will fail behind any NAT',
      );
    }
    // forceRelay is preserved rather than defaulted: it is a separate field on the config
    // (applied as iceTransportPolicy) that the receiver service sets, not part of the list.
    return RtcIceServerConfig(servers, forceRelay: config.forceRelay);
  }
}
