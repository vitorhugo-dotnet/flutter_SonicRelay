import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/features/pairing/data/pairing_repository.dart';
import 'package:sonic_relay/features/pairing/domain/device_pairing.dart';
import 'package:sonic_relay/features/pairing/domain/pairing_challenge_payload.dart';
import 'package:sonic_relay/features/pairing/presentation/pairing_page.dart';
import 'package:sonic_relay/features/pairing/presentation/pairing_view_model.dart';

const challengeId = '00000000-0000-0000-0000-000000000001';

void main() {
  testWidgets('keeps QR scan and manual pairing separate from session join', (
    tester,
  ) async {
    final repository = _FakePairingRepository();
    await tester.pumpWidget(_app(repository));

    expect(find.text('Scan QR code'), findsOneWidget);
    expect(find.byKey(const Key('pairing-challenge-id')), findsOneWidget);
    expect(find.byKey(const Key('pairing-code')), findsOneWidget);
    expect(find.text('Join stream'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('pairing-challenge-id')),
      challengeId,
    );
    await tester.enterText(find.byKey(const Key('pairing-code')), 'abc12345');
    await tester.tap(find.widgetWithText(FilledButton, 'Pair device'));
    await tester.pumpAndSettle();

    expect(repository.payload?.challengeId, challengeId);
    expect(repository.payload?.code, 'ABC12345');
    expect(find.text('Device paired.'), findsOneWidget);
  });

  testWidgets('shows generic invalid or expired pairing copy', (tester) async {
    final repository = _FakePairingRepository()
      ..failure = const PairingFailure(
        PairingFailureKind.invalidOrExpired,
        'This pairing code is invalid or expired. Request a new code.',
      );
    await tester.pumpWidget(_app(repository));

    await tester.enterText(
      find.byKey(const Key('pairing-challenge-id')),
      challengeId,
    );
    await tester.enterText(find.byKey(const Key('pairing-code')), 'ABC12345');
    await tester.tap(find.widgetWithText(FilledButton, 'Pair device'));
    await tester.pumpAndSettle();

    expect(
      find.text('This pairing code is invalid or expired. Request a new code.'),
      findsOneWidget,
    );
  });
}

Widget _app(_FakePairingRepository repository) => ProviderScope(
  overrides: [pairingRepositoryProvider.overrideWithValue(repository)],
  child: const MaterialApp(home: PairingPage()),
);

class _FakePairingRepository implements PairingRepository {
  PairingChallengePayload? payload;
  PairingFailure? failure;

  @override
  Future<DevicePairing> complete(PairingChallengePayload payload) async {
    this.payload = payload;
    if (failure case final value?) throw value;
    return DevicePairing(
      pairingId: 'pairing-1',
      publisherDeviceId: 'publisher-1',
      viewerDeviceId: 'viewer-1',
      status: 'active',
      createdAt: DateTime.utc(2026, 7, 29),
    );
  }

  @override
  Future<List<DevicePairing>> list(String deviceId) async => const [];

  @override
  Future<void> revoke(String pairingId) async {}
}
