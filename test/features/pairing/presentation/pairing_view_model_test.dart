import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/features/pairing/data/pairing_repository.dart';
import 'package:sonic_relay/features/pairing/domain/device_pairing.dart';
import 'package:sonic_relay/features/pairing/domain/pairing_challenge_payload.dart';
import 'package:sonic_relay/features/pairing/presentation/pairing_view_model.dart';

const challengeId = '00000000-0000-0000-0000-000000000001';
final pairedDevice = DevicePairing(
  pairingId: 'pairing-1',
  publisherDeviceId: 'publisher-1',
  viewerDeviceId: 'viewer-1',
  status: 'active',
  createdAt: DateTime.utc(2026, 7, 29),
);
final secondPairedDevice = DevicePairing(
  pairingId: 'pairing-2',
  publisherDeviceId: 'publisher-2',
  viewerDeviceId: 'viewer-1',
  status: 'active',
  createdAt: DateTime.utc(2026, 7, 29, 1),
);

void main() {
  test(
    'manual pairing submits pairing fields and not a session join code',
    () async {
      final repository = _FakePairingRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final viewModel = container.read(pairingViewModelProvider.notifier);

      viewModel.updateChallengeId(' $challengeId ');
      viewModel.updatePairingCode(' abc12345 ');
      await viewModel.completeManual();

      expect(repository.completedPayload?.challengeId, challengeId);
      expect(repository.completedPayload?.code, 'ABC12345');
      final state = container.read(pairingViewModelProvider);
      expect(state.status, PairingStatus.paired);
      expect(state.pairings.single.pairingId, 'pairing-1');
      expect(state.challengeId, isEmpty);
      expect(state.pairingCode, isEmpty);
    },
  );

  test('invalid or expired challenge exposes only generic copy', () async {
    final repository = _FakePairingRepository()
      ..failure = const PairingFailure(
        PairingFailureKind.invalidOrExpired,
        'This pairing code is invalid or expired. Request a new code.',
      );
    final container = _container(repository);
    addTearDown(container.dispose);
    final viewModel = container.read(pairingViewModelProvider.notifier);

    viewModel.updateChallengeId(challengeId);
    viewModel.updatePairingCode('ABC12345');
    await viewModel.completeManual();

    expect(
      container.read(pairingViewModelProvider).errorMessage,
      'This pairing code is invalid or expired. Request a new code.',
    );
  });

  test('first accepted scan starts only one completion request', () async {
    final pending = Completer<DevicePairing>();
    final repository = _FakePairingRepository()..pendingCompletion = pending;
    final container = _container(repository);
    addTearDown(container.dispose);
    final viewModel = container.read(pairingViewModelProvider.notifier);
    const raw = '{"challengeId":"$challengeId","code":"ABC12345"}';

    final first = viewModel.completeScanned(raw);
    final duplicate = viewModel.completeScanned(raw);
    await duplicate;

    expect(repository.completeCalls, 1);
    pending.complete(pairedDevice);
    await first;
    expect(container.read(pairingViewModelProvider).pairingCode, isEmpty);
  });

  test('scan submission can retry after a failed completion', () async {
    final repository = _FakePairingRepository()..completionFailures = 1;
    final container = _container(repository);
    addTearDown(container.dispose);
    final viewModel = container.read(pairingViewModelProvider.notifier);
    const raw = '{"challengeId":"$challengeId","code":"ABC12345"}';

    await viewModel.completeScanned(raw);
    expect(
      container.read(pairingViewModelProvider).status,
      PairingStatus.failed,
    );

    await viewModel.completeScanned(raw);

    expect(repository.completeCalls, 2);
    expect(
      container.read(pairingViewModelProvider).status,
      PairingStatus.paired,
    );
  });

  test('scan submission allows a later independent pairing', () async {
    final repository = _FakePairingRepository()
      ..completionResults = [pairedDevice, secondPairedDevice];
    final container = _container(repository);
    addTearDown(container.dispose);
    final viewModel = container.read(pairingViewModelProvider.notifier);

    await viewModel.completeScanned(
      '{"challengeId":"$challengeId","code":"ABC12345"}',
    );
    await viewModel.completeScanned(
      '{"challengeId":"00000000-0000-0000-0000-000000000002","code":"DEF67890"}',
    );

    expect(repository.completeCalls, 2);
    expect(
      container
          .read(pairingViewModelProvider)
          .pairings
          .map((pairing) => pairing.pairingId),
      ['pairing-2', 'pairing-1'],
    );
  });

  test('list and revoke update active pairings', () async {
    final repository = _FakePairingRepository()..listed = [pairedDevice];
    final container = _container(repository);
    addTearDown(container.dispose);
    final viewModel = container.read(pairingViewModelProvider.notifier);

    await viewModel.load('viewer-1');
    expect(container.read(pairingViewModelProvider).pairings, [pairedDevice]);

    await viewModel.revoke('pairing-1');
    expect(repository.revokedPairingId, 'pairing-1');
    expect(container.read(pairingViewModelProvider).pairings, isEmpty);
  });

  test(
    'revoke coalesces duplicate submissions while DELETE is in flight',
    () async {
      final pending = Completer<void>();
      final repository = _FakePairingRepository()
        ..listed = [pairedDevice]
        ..pendingRevoke = pending;
      final container = _container(repository);
      addTearDown(container.dispose);
      final viewModel = container.read(pairingViewModelProvider.notifier);
      await viewModel.load('viewer-1');

      final first = viewModel.revoke('pairing-1');
      final duplicate = viewModel.revoke('pairing-1');
      await duplicate;

      expect(repository.revokeCalls, 1);
      expect(container.read(pairingViewModelProvider).revokingPairingIds, {
        'pairing-1',
      });

      pending.complete();
      await first;
      final state = container.read(pairingViewModelProvider);
      expect(state.revokingPairingIds, isEmpty);
      expect(state.pairings, isEmpty);
    },
  );
}

ProviderContainer _container(_FakePairingRepository repository) =>
    ProviderContainer(
      overrides: [pairingRepositoryProvider.overrideWithValue(repository)],
    );

class _FakePairingRepository implements PairingRepository {
  PairingChallengePayload? completedPayload;
  PairingFailure? failure;
  Completer<DevicePairing>? pendingCompletion;
  List<DevicePairing> listed = const [];
  String? revokedPairingId;
  Completer<void>? pendingRevoke;
  int revokeCalls = 0;
  int completeCalls = 0;
  int completionFailures = 0;
  List<DevicePairing> completionResults = [];

  @override
  Future<DevicePairing> complete(PairingChallengePayload payload) async {
    completeCalls += 1;
    completedPayload = payload;
    if (completionFailures > 0) {
      completionFailures -= 1;
      throw const PairingFailure(
        PairingFailureKind.invalidOrExpired,
        'This pairing code is invalid or expired. Request a new code.',
      );
    }
    if (failure case final value?) throw value;
    if (pendingCompletion case final pending?) return pending.future;
    if (completionResults.isNotEmpty) return completionResults.removeAt(0);
    return pairedDevice;
  }

  @override
  Future<List<DevicePairing>> list(String deviceId) async => listed;

  @override
  Future<void> revoke(String pairingId) async {
    revokeCalls += 1;
    revokedPairingId = pairingId;
    if (pendingRevoke case final pending?) await pending.future;
  }
}
