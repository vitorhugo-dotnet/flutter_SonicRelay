import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/features/device_identity/data/device_identity_api.dart';
import 'package:sonic_relay/features/device_identity/data/dto/bootstrap_device_request.dart';
import 'package:sonic_relay/features/device_identity/data/dto/device_token_request.dart';

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

void main() {
  test(
    'bootstrap sends the viewer identity and parses its credential',
    () async {
      late RequestOptions captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _CallbackAdapter((options) {
          captured = options;
          return _jsonResponse({
            'deviceId': 'device-1',
            'credentialSecret': 'secret-1',
            'credentialVersion': 3,
          });
        });

      final result = await DioDeviceIdentityApi(dio).bootstrap(
        const BootstrapDeviceRequest(
          name: 'Pixel 9',
          deviceType: 'flutter_viewer',
          platform: 'android',
        ),
      );

      expect(captured.method, 'POST');
      expect(captured.path, '/api/devices/bootstrap');
      expect(captured.data, {
        'name': 'Pixel 9',
        'deviceType': 'flutter_viewer',
        'platform': 'android',
      });
      expect(captured.extra['skipAuth'], isTrue);
      expect(result.deviceId, 'device-1');
      expect(result.credentialSecret, 'secret-1');
      expect(result.credentialVersion, 3);
    },
  );

  test('token sends the stored credential and parses scopes', () async {
    late RequestOptions captured;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = _CallbackAdapter((options) {
        captured = options;
        return _jsonResponse({
          'accessToken': 'access-1',
          'expiresAt': '2026-07-29T15:00:00Z',
          'scopes': ['stream:listen', 'pairing:write'],
        });
      });

    final result = await DioDeviceIdentityApi(dio).token(
      const DeviceTokenRequest(
        deviceId: 'device-1',
        credentialSecret: 'secret-1',
      ),
    );

    expect(captured.method, 'POST');
    expect(captured.path, '/api/devices/token');
    expect(captured.data, {
      'deviceId': 'device-1',
      'credentialSecret': 'secret-1',
    });
    expect(captured.extra['skipAuth'], isTrue);
    expect(result.accessToken, 'access-1');
    expect(result.expiresAt, DateTime.utc(2026, 7, 29, 15));
    expect(result.scopes, ['stream:listen', 'pairing:write']);
  });
}

ResponseBody _jsonResponse(Map<String, Object?> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
