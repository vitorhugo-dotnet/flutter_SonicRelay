import 'package:dio/dio.dart';
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
  bool fetchShouldFail = false;
  bool updateShouldFail = false;
  List<String>? lastUpdateTurnUris;
  int fetchCallCount = 0;

  @override
  Future<RelaySettingsResult> fetch() async {
    fetchCallCount += 1;
    if (fetchShouldFail) throw Exception('network down');
    return fetchResult;
  }

  @override
  Future<RelaySettingsResult> update({String? relayMode, List<String>? turnUris}) async {
    if (updateShouldFail) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/settings/relay'),
        message: 'connection refused at 10.0.0.5:443',
      );
    }
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

  testWidgets('a failed load shows a retry affordance instead of an editable blank field', (
    tester,
  ) async {
    final api = _FakeRelaySettingsApi()..fetchShouldFail = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [relaySettingsApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: Scaffold(body: CoturnUrlField())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load the current coturn URL.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Save coturn URL'), findsNothing);

    api.fetchShouldFail = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('turn:existing.example.com:3478'), findsOneWidget);
    expect(api.fetchCallCount, 2);
  });

  testWidgets('rejects an invalid coturn URL without saving', (tester) async {
    final api = _FakeRelaySettingsApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [relaySettingsApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: Scaffold(body: CoturnUrlField())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'not-a-turn-url');
    await tester.tap(find.widgetWithText(FilledButton, 'Save coturn URL'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a valid TURN URL, e.g. turn:your-coturn-server.example.com:3478'),
      findsOneWidget,
    );
    expect(api.lastUpdateTurnUris, isNull);
  });

  testWidgets('a failed save shows a generic message, not the raw error', (tester) async {
    final api = _FakeRelaySettingsApi()..updateShouldFail = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [relaySettingsApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: Scaffold(body: CoturnUrlField())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'turn:new-coturn.example.com:3478');
    await tester.tap(find.widgetWithText(FilledButton, 'Save coturn URL'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save the coturn URL. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('10.0.0.5'), findsNothing);
  });
}
