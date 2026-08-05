import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/core/storage/relay_mode_storage.dart';
import 'package:sonic_relay/core/webrtc/relay_modes.dart';
import 'package:sonic_relay/core/webrtc/relay_settings_api.dart';
import 'package:sonic_relay/features/settings/presentation/settings_page.dart';

class _FakeRelaySettingsApi implements RelaySettingsApi {
  @override
  Future<RelaySettingsResult> fetch() async => const RelaySettingsResult(
    relayMode: RelayModes.automatic,
    turnUris: [],
    hasCustomTurnSecret: false,
  );

  @override
  Future<RelaySettingsResult> update({String? relayMode, List<String>? turnUris}) async =>
      RelaySettingsResult(
        relayMode: relayMode ?? RelayModes.automatic,
        turnUris: turnUris ?? const [],
        hasCustomTurnSecret: false,
      );
}

class _FakeRelayModeStorage extends RelayModeStorage {
  _FakeRelayModeStorage() : super(const FlutterSecureStorage());

  String stored = RelayModes.automatic;

  @override
  Future<String> read() async => stored;

  @override
  Future<void> write(String mode) async => stored = mode;
}

class _ReadyReadinessNotifier extends DeviceReadinessNotifier {
  @override
  DeviceReadinessState build() => const DeviceReadinessState.ready();
}

class _PairingRequiredReadinessNotifier extends DeviceReadinessNotifier {
  @override
  DeviceReadinessState build() => const DeviceReadinessState.pairingRequired();
}

Future<void> _pumpSettings(
  WidgetTester tester,
  DeviceReadinessNotifier Function() readinessNotifierFactory,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deviceReadinessProvider.overrideWith(readinessNotifierFactory),
        diagnosticsDirectoryProvider.overrideWithValue(
          Directory.systemTemp.createTempSync('sonicrelay_settings_test_').path,
        ),
        relaySettingsApiProvider.overrideWithValue(_FakeRelaySettingsApi()),
        relayModeStorageProvider.overrideWithValue(_FakeRelayModeStorage()),
      ],
      child: const MaterialApp(home: SettingsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the coturn section is visible once the device is paired', (tester) async {
    await _pumpSettings(tester, _ReadyReadinessNotifier.new);

    expect(find.text('Coturn'), findsOneWidget);
  });

  testWidgets('the coturn section is hidden before pairing completes', (tester) async {
    await _pumpSettings(tester, _PairingRequiredReadinessNotifier.new);

    expect(find.text('Coturn'), findsNothing);
  });
}
