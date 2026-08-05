/// The three mutually-exclusive relay policies, matching the backend's RelayModes
/// (dotnet_SonicRelay's SonicRelay.Domain.RelaySettings.RelayModes) and
/// windows_SonicRelay's Core.Configuration.RelayModes string-for-string, so the value
/// round-trips through /api/settings/relay unchanged across every client.
class RelayModes {
  const RelayModes._();

  static const automatic = 'automatic';
  static const forceRelay = 'forceRelay';
  static const disableFallback = 'disableFallback';

  static bool isValid(String? value) =>
      value == automatic || value == forceRelay || value == disableFallback;
}
