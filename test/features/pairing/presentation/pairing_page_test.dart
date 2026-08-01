import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/features/pairing/data/pairing_repository.dart';
import 'package:sonic_relay/features/pairing/domain/device_pairing.dart';
import 'package:sonic_relay/features/pairing/domain/pairing_challenge_payload.dart';
import 'package:sonic_relay/features/pairing/presentation/pairing_page.dart';
import 'package:sonic_relay/features/pairing/presentation/pairing_view_model.dart';

const challengeId = '00000000-0000-0000-0000-000000000001';
final existingPairing = DevicePairing(
  pairingId: 'pairing-existing',
  publisherDeviceId: 'publisher-existing',
  viewerDeviceId: 'viewer-1',
  status: 'active',
  createdAt: DateTime.utc(2026, 7, 29),
);

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

  testWidgets('loads current device pairings once when the page opens', (
    tester,
  ) async {
    final repository = _FakePairingRepository()..listed = [existingPairing];
    await tester.pumpWidget(_app(repository, deviceId: 'viewer-1'));
    await tester.pumpAndSettle();

    expect(repository.listCalls, 1);
    expect(repository.listedDeviceId, 'viewer-1');
    expect(find.text('Publisher publisher-existing'), findsOneWidget);

    tester.view.physicalSize = const Size(700, 1100);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pump();

    expect(repository.listCalls, 1);
  });

  testWidgets('canceling revoke confirmation does not send DELETE', (
    tester,
  ) async {
    final repository = _FakePairingRepository()..listed = [existingPairing];
    await tester.pumpWidget(_app(repository, deviceId: 'viewer-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();
    expect(find.text('Revoke pairing?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.revokeCalls, 0);
    expect(find.text('Publisher publisher-existing'), findsOneWidget);
  });

  testWidgets('confirming revoke sends one DELETE and updates the list', (
    tester,
  ) async {
    final repository = _FakePairingRepository()..listed = [existingPairing];
    await tester.pumpWidget(_app(repository, deviceId: 'viewer-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revoke pairing'));
    await tester.pumpAndSettle();

    expect(repository.revokeCalls, 1);
    expect(repository.revokedPairingId, 'pairing-existing');
    expect(find.text('Publisher publisher-existing'), findsNothing);
  });
}

Widget _app(_FakePairingRepository repository, {String? deviceId}) =>
    ProviderScope(
      overrides: [
        pairingRepositoryProvider.overrideWithValue(repository),
        currentPairingDeviceIdProvider.overrideWithValue(() async => deviceId),
      ],
      child: const MaterialApp(home: PairingPage()),
    );

class _FakePairingRepository implements PairingRepository {
  PairingChallengePayload? payload;
  PairingFailure? failure;
  List<DevicePairing> listed = const [];
  int listCalls = 0;
  String? listedDeviceId;
  int revokeCalls = 0;
  String? revokedPairingId;

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
  Future<List<DevicePairing>> list(String deviceId) async {
    listCalls += 1;
    listedDeviceId = deviceId;
    return listed;
  }

  @override
  Future<void> revoke(String pairingId) async {
    revokeCalls += 1;
    revokedPairingId = pairingId;
  }
}
