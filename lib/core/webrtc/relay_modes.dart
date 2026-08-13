/// The three mutually-exclusive relay policies, matching the backend's RelayModes
/// (dotnet_SonicRelay's SonicRelay.Domain.RelaySettings.RelayModes) and
/// windows_SonicRelay's Core.Configuration.RelayModes string-for-string. Each client now
/// stores its own choice locally rather than syncing it through the backend, but the literal
/// values still need to match across all three so they mean the same thing everywhere.
class RelayModes {
  const RelayModes._();

  static const automatic = 'automatic';
  static const forceRelay = 'forceRelay';
  static const disableFallback = 'disableFallback';

  static bool isValid(String? value) =>
      value == automatic || value == forceRelay || value == disableFallback;
}
