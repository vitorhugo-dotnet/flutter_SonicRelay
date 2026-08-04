import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/core/webrtc/relay_settings_api.dart';
import 'package:sonic_relay/features/settings/presentation/widgets/coturn_url_field.dart';

class _FakeRelaySettingsApi implements RelaySettingsApi {
  RelaySettingsResult fetchResult = const RelaySettingsResult(
    relayMode: 'automatic',
    turnUris: ['turn:existing.example.com:3478'],
    hasCustomTurnSecret: false,
  );
  List<String>? lastUpdateTurnUris;

  @override
  Future<RelaySettingsResult> fetch() async => fetchResult;

  @override
  Future<RelaySettingsResult> update({String? relayMode, List<String>? turnUris}) async {
    lastUpdateTurnUris = turnUris;
    return RelaySettingsResult(
      relayMode: relayMode ?? fetchResult.relayMode,
      turnUris: turnUris ?? fetchResult.turnUris,
      hasCustomTurnSecret: fetchResult.hasCustomTurnSecret,
    );
  }
}

void main() {
  testWidgets('loads the current coturn URL and saves a new one', (tester) async {
    final api = _FakeRelaySettingsApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [relaySettingsApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: Scaffold(body: CoturnUrlField())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('turn:existing.example.com:3478'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'turn:new-coturn.example.com:3478',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save coturn URL'));
    await tester.pumpAndSettle();

    expect(api.lastUpdateTurnUris, ['turn:new-coturn.example.com:3478']);
  });
}
