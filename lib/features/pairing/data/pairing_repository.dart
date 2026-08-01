import 'package:dio/dio.dart';

import '../domain/device_pairing.dart';
import '../domain/pairing_challenge_payload.dart';
import 'pairing_api.dart';

enum PairingFailureKind {
  invalidOrExpired,
  unauthorized,
  network,
  invalidResponse,
}

class PairingFailure implements Exception {
  const PairingFailure(this.kind, this.message);

  final PairingFailureKind kind;
  final String message;
}

class PairingRepository {
  const PairingRepository({required PairingApi api}) : _api = api;

  final PairingApi _api;

  Future<DevicePairing> complete(PairingChallengePayload payload) async {
    try {
      return await _api.complete(payload);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 400 || status == 404 || status == 410) {
        throw const PairingFailure(
          PairingFailureKind.invalidOrExpired,
          'This pairing code is invalid or expired. Request a new code.',
        );
      }
      throw _mapCommonFailure(status);
    } on FormatException {
      throw const PairingFailure(
        PairingFailureKind.invalidResponse,
        'The server returned invalid pairing data. Please retry.',
      );
    }
  }

  Future<List<DevicePairing>> list(String deviceId) async {
    try {
      return await _api.list(deviceId);
    } on DioException catch (error) {
      throw _mapCommonFailure(error.response?.statusCode);
    } on FormatException {
      throw const PairingFailure(
        PairingFailureKind.invalidResponse,
        'The server returned invalid pairing data. Please retry.',
      );
    }
  }

  Future<void> revoke(String pairingId) async {
    try {
      await _api.revoke(pairingId);
    } on DioException catch (error) {
      throw _mapCommonFailure(error.response?.statusCode);
    }
  }

  PairingFailure _mapCommonFailure(int? status) {
    if (status == 401 || status == 403) {
      return const PairingFailure(
        PairingFailureKind.unauthorized,
        'This device is not authorized to manage that pairing.',
      );
    }
    return const PairingFailure(
      PairingFailureKind.network,
      'Unable to manage device pairing. Check your connection and retry.',
    );
  }
}
