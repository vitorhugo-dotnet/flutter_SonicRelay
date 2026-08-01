import 'package:dio/dio.dart';

import '../domain/device_pairing.dart';
import '../domain/pairing_challenge_payload.dart';

abstract interface class PairingApi {
  Future<DevicePairing> complete(PairingChallengePayload payload);

  Future<List<DevicePairing>> list(String deviceId);

  Future<void> revoke(String pairingId);
}

class DioPairingApi implements PairingApi {
  const DioPairingApi(this._dio);

  final Dio _dio;

  @override
  Future<DevicePairing> complete(PairingChallengePayload payload) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/api/pairings/complete',
      data: {'challengeId': payload.challengeId, 'code': payload.code},
    );
    return DevicePairing.fromJson(response.data!);
  }

  @override
  Future<List<DevicePairing>> list(String deviceId) async {
    final response = await _dio.get<List<Object?>>(
      '/api/devices/$deviceId/pairings',
    );
    return response.data!
        .cast<Map<String, Object?>>()
        .map(DevicePairing.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> revoke(String pairingId) =>
      _dio.delete<void>('/api/pairings/$pairingId');
}
