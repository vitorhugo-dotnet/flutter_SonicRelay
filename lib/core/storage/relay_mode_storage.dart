import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../webrtc/relay_modes.dart';

/// Last-known-good cache of the server-synced relay mode (issue #26 follow-up — this used
/// to be the sole source of truth for a local-only "force relay" boolean; the real source of
/// truth is now the backend's /api/settings/relay).
class RelayModeStorage {
  const RelayModeStorage(this._storage);

  static const _modeKey = 'webrtc.relayMode';
  static const _legacyForceRelayKey = 'webrtc.forceRelay';

  final FlutterSecureStorage _storage;

  Future<String> read() async {
    final stored = await _storage.read(key: _modeKey);
    if (stored != null && RelayModes.isValid(stored)) return stored;
    // Migrate the pre-existing boolean-only flag (issue #26 predecessor).
    final legacy = await _storage.read(key: _legacyForceRelayKey);
    return legacy == 'true' ? RelayModes.forceRelay : RelayModes.automatic;
  }

  Future<void> write(String mode) => _storage.write(key: _modeKey, value: mode);
}
