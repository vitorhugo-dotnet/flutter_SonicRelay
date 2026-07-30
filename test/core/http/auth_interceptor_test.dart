import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/core/http/auth_interceptor.dart';
import 'package:sonic_relay/features/device_identity/data/device_identity_session.dart';

class FakeDeviceIdentitySession implements DeviceIdentitySession {
  FakeDeviceIdentitySession(List<String> tokens)
    : _tokens = List<String>.from(tokens);

  final List<String> _tokens;
  final List<bool> forceRefreshes = [];
  String? _cachedToken;
  Object? forceRefreshError;

  @override
  Future<String> accessToken({bool forceRefresh = false}) async {
    forceRefreshes.add(forceRefresh);
    if (forceRefresh) {
      if (forceRefreshError case final error?) throw error;
    } else {
      if (_cachedToken case final cached?) return cached;
    }
    return _cachedToken = _tokens.removeAt(0);
  }

  @override
  Future<void> reset() async {}
}

class CallbackAdapter implements HttpClientAdapter {
  CallbackAdapter(this.callback);

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
  test('adds a DeviceBearer token to an authenticated request', () async {
    final identity = FakeDeviceIdentitySession(['token-1']);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = CallbackAdapter((options) {
      expect(options.headers['Authorization'], 'DeviceBearer token-1');
      return ResponseBody.fromString('ok', 200);
    });
    dio.interceptors.add(
      AuthInterceptor(deviceIdentitySession: identity, replayDio: Dio()),
    );

    final response = await dio.get<String>('/protected');

    expect(response.statusCode, 200);
    expect(identity.forceRefreshes, [false]);
  });

  test('401 forces one exchange and replays a GET once', () async {
    final identity = FakeDeviceIdentitySession(['token-1', 'token-2']);
    final replayDio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    replayDio.httpClientAdapter = CallbackAdapter((options) {
      expect(options.headers['Authorization'], 'DeviceBearer token-2');
      return ResponseBody.fromString('ok', 200);
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = CallbackAdapter(
      (_) => ResponseBody.fromString('unauthorized', 401),
    );
    dio.interceptors.add(
      AuthInterceptor(deviceIdentitySession: identity, replayDio: replayDio),
    );

    final response = await dio.get<String>('/protected');

    expect(response.statusCode, 200);
    expect(identity.forceRefreshes, [false, true]);
  });

  test('401 refreshes but never replays an unsafe pairing POST', () async {
    final identity = FakeDeviceIdentitySession(['token-1', 'token-2']);
    var replayCalls = 0;
    var mutationCalls = 0;
    final authorizationHeaders = <String?>[];
    final replayDio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    replayDio.httpClientAdapter = CallbackAdapter((_) {
      replayCalls++;
      return ResponseBody.fromString('ok', 200);
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = CallbackAdapter((options) {
      mutationCalls++;
      authorizationHeaders.add(options.headers['Authorization'] as String?);
      return mutationCalls == 1
          ? ResponseBody.fromString('unauthorized', 401)
          : ResponseBody.fromString('ok', 200);
    });
    dio.interceptors.add(
      AuthInterceptor(deviceIdentitySession: identity, replayDio: replayDio),
    );

    await expectLater(
      dio.post<String>('/api/pairings/complete', data: {'code': 'PAIR1234'}),
      throwsA(isA<DioException>()),
    );

    expect(replayCalls, 0);
    expect(mutationCalls, 1);
    expect(identity.forceRefreshes, [false, true]);

    final response = await dio.post<String>(
      '/api/pairings/complete',
      data: {'code': 'PAIR1234'},
    );

    expect(response.statusCode, 200);
    expect(replayCalls, 0);
    expect(mutationCalls, 2);
    expect(authorizationHeaders, [
      'DeviceBearer token-1',
      'DeviceBearer token-2',
    ]);
    expect(identity.forceRefreshes, [false, true, false]);
  });

  test(
    'unsafe POST refresh propagates permanent identity invalidation',
    () async {
      final identity = FakeDeviceIdentitySession(['token-1'])
        ..forceRefreshError = const DeviceIdentitySessionInvalidatedException();
      var mutationCalls = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = CallbackAdapter((_) {
        mutationCalls++;
        return ResponseBody.fromString('unauthorized', 401);
      });
      dio.interceptors.add(
        AuthInterceptor(deviceIdentitySession: identity, replayDio: Dio()),
      );

      await expectLater(
        dio.post<String>('/api/pairings/complete', data: {'code': 'PAIR1234'}),
        throwsA(isA<DioException>()),
      );

      expect(mutationCalls, 1);
      expect(identity.forceRefreshes, [false, true]);
    },
  );

  test('replaySafe explicitly permits one POST replay', () async {
    final identity = FakeDeviceIdentitySession(['token-1', 'token-2']);
    final replayDio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    replayDio.httpClientAdapter = CallbackAdapter((options) {
      expect(options.method, 'POST');
      expect(options.headers['Authorization'], 'DeviceBearer token-2');
      return ResponseBody.fromString('ok', 200);
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = CallbackAdapter(
      (_) => ResponseBody.fromString('unauthorized', 401),
    );
    dio.interceptors.add(
      AuthInterceptor(deviceIdentitySession: identity, replayDio: replayDio),
    );

    final response = await dio.post<String>(
      '/safe',
      data: {'value': 1},
      options: Options(extra: const {'replaySafe': true}),
    );

    expect(response.statusCode, 200);
    expect(identity.forceRefreshes, [false, true]);
  });
}
