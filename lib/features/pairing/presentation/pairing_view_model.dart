import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../data/pairing_api.dart';
import '../data/pairing_repository.dart';
import '../domain/device_pairing.dart';
import '../domain/pairing_challenge_payload.dart';

enum PairingStatus { idle, loading, submitting, paired, failed }

class PairingState {
  const PairingState({
    this.challengeId = '',
    this.pairingCode = '',
    this.status = PairingStatus.idle,
    this.pairings = const [],
    this.errorMessage,
  });

  final String challengeId;
  final String pairingCode;
  final PairingStatus status;
  final List<DevicePairing> pairings;
  final String? errorMessage;

  bool get isBusy =>
      status == PairingStatus.loading || status == PairingStatus.submitting;
}

final pairingRepositoryProvider = Provider<PairingRepository>(
  (ref) => PairingRepository(api: DioPairingApi(ref.watch(dioProvider))),
);

final pairingViewModelProvider =
    NotifierProvider<PairingViewModel, PairingState>(PairingViewModel.new);

class PairingViewModel extends Notifier<PairingState> {
  late final PairingRepository _repository;
  bool _scanAccepted = false;

  @override
  PairingState build() {
    _repository = ref.watch(pairingRepositoryProvider);
    return const PairingState();
  }

  void updateChallengeId(String value) {
    state = PairingState(
      challengeId: value.trim(),
      pairingCode: state.pairingCode,
      pairings: state.pairings,
    );
  }

  void updatePairingCode(String value) {
    state = PairingState(
      challengeId: state.challengeId,
      pairingCode: value.trim().toUpperCase(),
      pairings: state.pairings,
    );
  }

  Future<void> completeManual() async {
    PairingChallengePayload payload;
    try {
      payload = PairingChallengePayload.parse(
        jsonEncode({
          'challengeId': state.challengeId,
          'code': state.pairingCode,
        }),
      );
    } on FormatException {
      state = PairingState(
        challengeId: state.challengeId,
        pairingCode: state.pairingCode,
        pairings: state.pairings,
        status: PairingStatus.failed,
        errorMessage: 'Enter a valid challenge ID and pairing code.',
      );
      return;
    }
    await _complete(payload);
  }

  Future<void> completeScanned(String raw) async {
    if (_scanAccepted) return;

    PairingChallengePayload payload;
    try {
      payload = PairingChallengePayload.parse(raw);
    } on FormatException {
      state = PairingState(
        challengeId: state.challengeId,
        pairingCode: state.pairingCode,
        pairings: state.pairings,
        status: PairingStatus.failed,
        errorMessage: 'Scan a valid SonicRelay pairing QR code.',
      );
      return;
    }

    _scanAccepted = true;
    await _complete(payload);
  }

  Future<void> load(String deviceId) async {
    state = PairingState(
      challengeId: state.challengeId,
      pairingCode: state.pairingCode,
      pairings: state.pairings,
      status: PairingStatus.loading,
    );
    try {
      final pairings = await _repository.list(deviceId);
      state = PairingState(pairings: pairings);
    } on PairingFailure catch (error) {
      _setFailure(error.message);
    } catch (_) {
      _setFailure('Unable to load device pairings. Please retry.');
    }
  }

  Future<void> revoke(String pairingId) async {
    try {
      await _repository.revoke(pairingId);
      state = PairingState(
        pairings: state.pairings
            .where((pairing) => pairing.pairingId != pairingId)
            .toList(growable: false),
      );
    } on PairingFailure catch (error) {
      _setFailure(error.message);
    } catch (_) {
      _setFailure('Unable to revoke device pairing. Please retry.');
    }
  }

  Future<void> _complete(PairingChallengePayload payload) async {
    if (state.status == PairingStatus.submitting) return;
    state = PairingState(
      challengeId: state.challengeId,
      pairingCode: state.pairingCode,
      pairings: state.pairings,
      status: PairingStatus.submitting,
    );
    try {
      final pairing = await _repository.complete(payload);
      final pairings = [
        pairing,
        ...state.pairings.where(
          (existing) => existing.pairingId != pairing.pairingId,
        ),
      ];
      state = PairingState(status: PairingStatus.paired, pairings: pairings);
    } on PairingFailure catch (error) {
      _setFailure(error.message);
    } catch (_) {
      _setFailure('Unable to pair this device. Please retry.');
    }
  }

  void _setFailure(String message) {
    state = PairingState(
      challengeId: state.challengeId,
      pairingCode: state.pairingCode,
      pairings: state.pairings,
      status: PairingStatus.failed,
      errorMessage: message,
    );
  }
}
