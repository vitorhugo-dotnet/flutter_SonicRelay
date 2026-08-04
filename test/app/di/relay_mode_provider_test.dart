import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/core/storage/relay_mode_storage.dart';
import 'package:sonic_relay/core/webrtc/relay_modes.dart';
import 'package:sonic_relay/core/webrtc/relay_settings_api.dart';

class _FakeRelayModeStorage extends RelayModeStorage {
  _FakeRelayModeStorage() : super(const FlutterSecureStorage());

  String? written;
  String stored = RelayModes.automatic;

  @override
  Future<String> read() async => stored;

  @override
  Future<void> write(String mode) async {
    written = mode;
    stored = mode;
  }
}

class _FakeRelaySettingsApi implements RelaySettingsApi {
  RelaySettingsResult updateResult = const RelaySettingsResult(
    relayMode: RelayModes.forceRelay,
    turnUris: [],
    hasCustomTurnSecret: false,
  );
  RelaySettingsResult fetchResult = const RelaySettingsResult(
    relayMode: RelayModes.disableFallback,
    turnUris: [],
    hasCustomTurnSecret: false,
  );
  String? lastUpdateRelayMode;

  @override
  Future<RelaySettingsResult> fetch() async => fetchResult;

  @override
  Future<RelaySettingsResult> update({String? relayMode, List<String>? turnUris}) async {
    lastUpdateRelayMode = relayMode;
    return updateResult;
  }
}

void main() {
  test(
    'RelayModeNotifier writes through the server-confirmed value on change, not the requested one',
    () async {
      final storage = _FakeRelayModeStorage();
      // The fake deliberately confirms a *different* mode than the one requested below, so
      // this test can only pass if the notifier applies `result.relayMode` (the server's
      // response) rather than the input `mode` directly — proving there's no local-only apply.
      final api = _FakeRelaySettingsApi()
        ..updateResult = const RelaySettingsResult(
          relayMode: RelayModes.disableFallback,
          turnUris: [],
          hasCustomTurnSecret: false,
        );
      final container = ProviderContainer(
        overrides: [
          relayModeStorageProvider.overrideWithValue(storage),
          relaySettingsApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(relayModeProvider), RelayModes.automatic);

      await container.read(relayModeProvider.notifier).set(RelayModes.forceRelay);

      expect(api.lastUpdateRelayMode, RelayModes.forceRelay);
      expect(container.read(relayModeProvider), RelayModes.disableFallback);
      expect(storage.written, RelayModes.disableFallback);
    },
  );

  test('refresh fetches the server value and applies it locally', () async {
    final storage = _FakeRelayModeStorage();
    final api = _FakeRelaySettingsApi();
    final container = ProviderContainer(
      overrides: [
        relayModeStorageProvider.overrideWithValue(storage),
        relaySettingsApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    await container.read(relayModeProvider.notifier).refresh();

    expect(container.read(relayModeProvider), RelayModes.disableFallback);
    expect(storage.written, RelayModes.disableFallback);
  });
}
