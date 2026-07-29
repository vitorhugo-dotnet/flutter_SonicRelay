import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/features/pairing/data/pairing_api.dart';
import 'package:sonic_relay/features/pairing/data/pairing_repository.dart';
import 'package:sonic_relay/features/pairing/domain/device_pairing.dart';
import 'package:sonic_relay/features/pairing/domain/pairing_challenge_payload.dart';

const payload = PairingChallengePayload(
  challengeId: '00000000-0000-0000-0000-000000000001',
  code: 'ABC12345',
);

const pairingJson = <String, Object?>{
  'pairingId': '00000000-0000-0000-0000-000000000010',
  'publisherDeviceId': '00000000-0000-0000-0000-000000000020',
  'viewerDeviceId': '00000000-0000-0000-0000-000000000030',
  'status': 'active',
  'createdAt': '2026-07-29T12:00:00Z',
  'lastUsedAt': '2026-07-29T12:01:00Z',
};

void main() {
  test('complete posts the minimal challenge with DeviceBearer', () async {
    late RequestOptions captured;
    final api = DioPairingApi(
      _authorizedDio((options) {
        captured = options;
        return _jsonResponse(pairingJson);
      }),
    );

    final pairing = await api.complete(payload);

    expect(captured.method, 'POST');
    expect(captured.path, '/api/pairings/complete');
    expect(captured.headers['Authorization'], 'DeviceBearer device-token');
    expect(captured.data, {
      'challengeId': payload.challengeId,
      'code': payload.code,
    });
    expect(pairing.pairingId, pairingJson['pairingId']);
    expect(pairing.viewerDeviceId, pairingJson['viewerDeviceId']);
  });

  test('list reads the current device pairings with DeviceBearer', () async {
    late RequestOptions captured;
    final api = DioPairingApi(
      _authorizedDio((options) {
        captured = options;
        return _jsonResponse([pairingJson]);
      }),
    );

    final pairings = await api.list('00000000-0000-0000-0000-000000000030');

    expect(captured.method, 'GET');
    expect(
      captured.path,
      '/api/devices/00000000-0000-0000-0000-000000000030/pairings',
    );
    expect(captured.headers['Authorization'], 'DeviceBearer device-token');
    expect(pairings, hasLength(1));
    expect(pairings.single.status, 'active');
  });

  test('revoke deletes the pairing with DeviceBearer', () async {
    late RequestOptions captured;
    final api = DioPairingApi(
      _authorizedDio((options) {
        captured = options;
        return ResponseBody.fromString('', 204);
      }),
    );

    await api.revoke('00000000-0000-0000-0000-000000000010');

    expect(captured.method, 'DELETE');
    expect(captured.path, '/api/pairings/00000000-0000-0000-0000-000000000010');
    expect(captured.headers['Authorization'], 'DeviceBearer device-token');
  });

  test('complete hides invalid or expired server details', () async {
    final api = _FakePairingApi()
      ..error = _dioFailure(
        400,
        'expired challenge credentialSecret=must-not-leak',
      );
    final repository = PairingRepository(api: api);

    await expectLater(
      repository.complete(payload),
      throwsA(
        isA<PairingFailure>()
            .having(
              (failure) => failure.kind,
              'kind',
              PairingFailureKind.invalidOrExpired,
            )
            .having(
              (failure) => failure.message,
              'message',
              'This pairing code is invalid or expired. Request a new code.',
            )
            .having(
              (failure) => failure.message,
              'redacted message',
              isNot(contains('credentialSecret')),
            ),
      ),
    );
  });

  test('repository delegates list and revoke', () async {
    final api = _FakePairingApi();
    final repository = PairingRepository(api: api);

    final pairings = await repository.list('viewer-1');
    await repository.revoke('pairing-1');

    expect(api.listedDeviceId, 'viewer-1');
    expect(api.revokedPairingId, 'pairing-1');
    expect(pairings.single.pairingId, pairingJson['pairingId']);
  });
}

class _CallbackAdapter implements HttpClientAdapter {
  _CallbackAdapter(this.callback);

  final ResponseBody Function(RequestOptions options) callback;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => callback(options);

  @override
  void close({bool force = false}) {}
}

Dio _authorizedDio(ResponseBody Function(RequestOptions options) callback) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = _CallbackAdapter(callback);
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['Authorization'] = 'DeviceBearer device-token';
        handler.next(options);
      },
    ),
  );
  return dio;
}

ResponseBody _jsonResponse(Object body) => ResponseBody.fromString(
  jsonEncode(body),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

DioException _dioFailure(int status, String error) {
  final options = RequestOptions(path: '/api/pairings/complete');
  return DioException(
    requestOptions: options,
    response: Response<Map<String, Object?>>(
      requestOptions: options,
      statusCode: status,
      data: {'error': error},
    ),
  );
}

class _FakePairingApi implements PairingApi {
  Object? error;
  String? listedDeviceId;
  String? revokedPairingId;

  @override
  Future<DevicePairing> complete(PairingChallengePayload payload) async {
    if (error case final value?) throw value;
    return DevicePairing.fromJson(pairingJson);
  }

  @override
  Future<List<DevicePairing>> list(String deviceId) async {
    listedDeviceId = deviceId;
    return [DevicePairing.fromJson(pairingJson)];
  }

  @override
  Future<void> revoke(String pairingId) async {
    revokedPairingId = pairingId;
  }
}
