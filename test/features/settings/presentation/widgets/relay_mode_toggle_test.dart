import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/core/storage/relay_mode_storage.dart';
import 'package:sonic_relay/core/webrtc/relay_modes.dart';
import 'package:sonic_relay/core/webrtc/relay_settings_api.dart';
import 'package:sonic_relay/features/settings/presentation/widgets/relay_mode_toggle.dart';

class _FakeRelayModeStorage extends RelayModeStorage {
  _FakeRelayModeStorage() : super(const FlutterSecureStorage());

  String stored = RelayModes.automatic;

  @override
  Future<String> read() async => stored;

  @override
  Future<void> write(String mode) async => stored = mode;
}

class _FakeRelaySettingsApi implements RelaySettingsApi {
  Object? updateError;

  @override
  Future<RelaySettingsResult> fetch() async => const RelaySettingsResult(
    relayMode: RelayModes.automatic,
    turnUris: [],
    hasCustomTurnSecret: false,
  );

  @override
  Future<RelaySettingsResult> update({String? relayMode, List<String>? turnUris}) async {
    if (updateError case final error?) throw error;
    return RelaySettingsResult(
      relayMode: relayMode ?? RelayModes.automatic,
      turnUris: const [],
      hasCustomTurnSecret: false,
    );
  }
}

void main() {
  testWidgets('selecting a mode updates the radio group on success', (tester) async {
    final api = _FakeRelaySettingsApi();
    await tester.pumpWidget(_app(api));

    await tester.tap(find.text('Force relay (TURN only)'));
    await tester.pumpAndSettle();

    final forceRelayTile = tester.widget<RadioListTile<String>>(
      find.widgetWithText(RadioListTile<String>, 'Force relay (TURN only)'),
    );
    expect(forceRelayTile.groupValue, RelayModes.forceRelay);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a failed save shows an error SnackBar and leaves the selection unchanged', (
    tester,
  ) async {
    final api = _FakeRelaySettingsApi()..updateError = Exception('network down');
    await tester.pumpWidget(_app(api));

    await tester.tap(find.text('Force relay (TURN only)'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save the relay mode. Please try again.'),
      findsOneWidget,
    );
    final automaticTile = tester.widget<RadioListTile<String>>(
      find.widgetWithText(RadioListTile<String>, 'Automatic'),
    );
    expect(automaticTile.groupValue, RelayModes.automatic);
  });
}

Widget _app(_FakeRelaySettingsApi api) => ProviderScope(
  overrides: [
    relaySettingsApiProvider.overrideWithValue(api),
    relayModeStorageProvider.overrideWithValue(_FakeRelayModeStorage()),
  ],
  child: const MaterialApp(
    home: Scaffold(body: RelayModeToggle()),
  ),
);
