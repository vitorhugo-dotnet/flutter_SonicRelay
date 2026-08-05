import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/core/webrtc/relay_settings_api.dart';

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

Dio _dioReturning(Map<String, Object?> body, {void Function(RequestOptions)? onRequest}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://sonicrelay-api.hugodotnet.dev'));
  dio.httpClientAdapter = _CallbackAdapter((options) {
    onRequest?.call(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  });
  return dio;
}

void main() {
  test('fetch parses relayMode, turnUris, and hasCustomTurnSecret', () async {
    final api = DioRelaySettingsApi(
      _dioReturning({
        'relayMode': 'forceRelay',
        'turnUris': ['turn:relay.example.com:3478'],
        'hasCustomTurnSecret': true,
      }),
    );

    final result = await api.fetch();

    expect(result.relayMode, 'forceRelay');
    expect(result.turnUris, ['turn:relay.example.com:3478']);
    expect(result.hasCustomTurnSecret, isTrue);
  });

  test('update sends a PUT with only the provided fields', () async {
    RequestOptions? sent;
    final api = DioRelaySettingsApi(
      _dioReturning(
        {'relayMode': 'disableFallback', 'turnUris': <String>[], 'hasCustomTurnSecret': false},
        onRequest: (options) => sent = options,
      ),
    );

    final result = await api.update(relayMode: 'disableFallback');

    expect(sent!.method, 'PUT');
    expect(sent!.path, '/api/settings/relay');
    expect(sent!.data, {'relayMode': 'disableFallback'});
    expect(result.relayMode, 'disableFallback');
  });

  test('a missing turnUris list defaults to empty', () async {
    final api = DioRelaySettingsApi(
      _dioReturning({'relayMode': 'automatic', 'hasCustomTurnSecret': false}),
    );

    final result = await api.fetch();

    expect(result.turnUris, isEmpty);
  });
}
