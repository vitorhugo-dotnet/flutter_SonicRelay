import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/app/sonic_relay_app.dart';
import 'package:sonic_relay/core/storage/relay_mode_storage.dart';
import 'package:sonic_relay/core/webrtc/relay_modes.dart';
import 'package:sonic_relay/core/webrtc/relay_settings_api.dart';
import 'package:sonic_relay/features/listener/presentation/listener_page.dart';
import 'package:sonic_relay/features/sessions/presentation/join_session_page.dart';
import 'package:sonic_relay/features/settings/presentation/settings_page.dart';

String _testDiagnosticsDirectory() =>
    Directory.systemTemp.createTempSync('sonicrelay_app_test_').path;

/// Settings' `CoturnUrlField` (visible once paired, see coturn_url_field.dart) fetches on
/// mount, and so does the Connection section's on-mount `relayModeProvider.refresh()`. Without
/// this override the real `DioRelaySettingsApi` schedules a connect-timeout timer that
/// outlives the widget tree once these tests move on without awaiting it, tripping Flutter
/// test's "A Timer is still pending" invariant.
class _FakeRelaySettingsApi implements RelaySettingsApi {
  @override
  Future<RelaySettingsResult> fetch() async => const RelaySettingsResult(
    relayMode: 'automatic',
    turnUris: [],
    hasCustomTurnSecret: false,
  );

  @override
  Future<RelaySettingsResult> update({String? relayMode, List<String>? turnUris}) async =>
      RelaySettingsResult(
        relayMode: relayMode ?? 'automatic',
        turnUris: turnUris ?? const [],
        hasCustomTurnSecret: false,
      );
}

/// Avoids the real `FlutterSecureStorage` plugin, which has no platform channel under
/// `flutter test` — the Connection section's on-mount refresh writes through this on success.
class _FakeRelayModeStorage extends RelayModeStorage {
  _FakeRelayModeStorage() : super(const FlutterSecureStorage());

  String stored = RelayModes.automatic;

  @override
  Future<String> read() async => stored;

  @override
  Future<void> write(String mode) async => stored = mode;
}

ProviderScope testApp() => ProviderScope(
  overrides: [
    deviceReadinessProvider.overrideWith(_ReadyReadinessNotifier.new),
    diagnosticsDirectoryProvider.overrideWithValue(
      _testDiagnosticsDirectory(),
    ),
    relaySettingsApiProvider.overrideWithValue(_FakeRelaySettingsApi()),
    relayModeStorageProvider.overrideWithValue(_FakeRelayModeStorage()),
  ],
  child: const SonicRelayApp(),
);

void main() {
  testWidgets('uses a dark Material 3 theme', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.useMaterial3, isTrue);
    expect(materialApp.theme?.brightness, Brightness.dark);
  });

  testWidgets('startup opens device-first join without any account UI', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.text('Join stream'), findsOneWidget);
    expect(find.text('Email'), findsNothing);
    expect(find.text('Password'), findsNothing);
  });

  testWidgets('feature pages show device-first presentation content', (
    tester,
  ) async {
    // Fixed once per test: the ProviderScope below is reused (updated, not
    // recreated) by Flutter's element diffing across the three pumpWidget
    // calls, since it has no distinguishing key. Regenerating this value on
    // every pumpPage call made diagnosticsDirectoryProvider look "changed" on
    // each pump, cascading an invalidation down to the non-autoDispose
    // listenerViewModelProvider and making it rebuild on its existing
    // Notifier instance — which crashed on the `late final` fields in
    // ListenerViewModel.build() already being set from the first pump.
    final diagnosticsDirectory = _testDiagnosticsDirectory();

    Future<void> pumpPage(Widget page) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceReadinessProvider.overrideWith(_ReadyReadinessNotifier.new),
            diagnosticsDirectoryProvider.overrideWithValue(
              diagnosticsDirectory,
            ),
            relaySettingsApiProvider.overrideWithValue(_FakeRelaySettingsApi()),
            relayModeStorageProvider.overrideWithValue(_FakeRelayModeStorage()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: page,
          ),
        ),
      );
    }

    await pumpPage(const JoinSessionPage());
    expect(find.text('Join stream'), findsOneWidget);

    await pumpPage(const ListenerPage());
    expect(find.text('Audio monitor'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('WebRTC / ICE'), findsOneWidget);

    await pumpPage(const SettingsPage());
    expect(find.text('Server'), findsOneWidget);
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Manage pairings'), findsOneWidget);
    expect(find.text('Reset device identity'), findsOneWidget);
    expect(find.text('Log out'), findsNothing);
    expect(find.text('Delete account'), findsNothing);
  });

  testWidgets('device-first startup fits a common small Android viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

class _ReadyReadinessNotifier extends DeviceReadinessNotifier {
  @override
  DeviceReadinessState build() => const DeviceReadinessState.ready();
}
