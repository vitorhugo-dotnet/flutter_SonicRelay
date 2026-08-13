import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../webrtc/relay_modes.dart';

/// Persists this device's local relay mode preference. Started as a local-only "force relay"
/// boolean, briefly synced through a backend row shared by the whole deployment (issue #26
/// follow-up), and is local-only again now that per-device preferences replaced that global
/// row.
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
