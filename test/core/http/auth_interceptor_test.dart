import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/core/http/auth_interceptor.dart';
import 'package:sonic_relay/core/storage/secure_token_storage.dart';
import 'package:sonic_relay/features/auth/domain/auth_session.dart';

class MemoryTokenStorage implements TokenStorage {
  MemoryTokenStorage(this.value);
  AuthSession? value;
  @override
  Future<void> clear() async => value = null;
  @override
  Future<AuthSession?> read() async => value;
  @override
  Future<void> write(AuthSession session) async => value = session;
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

ResponseBody jsonResponse(String body, int status) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  const oldSession = AuthSession(
    accessToken: 'old',
    refreshToken: 'refresh',
    expiresIn: 1,
    tokenType: 'Bearer',
  );

  test('401 refreshes tokens and retries the original request once', () async {
    final storage = MemoryTokenStorage(oldSession);
    final refreshDio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    refreshDio.httpClientAdapter = CallbackAdapter((options) {
      if (options.path == '/auth/refresh') {
        return jsonResponse(
          '{"accessToken":"new","refreshToken":"new-refresh",'
          '"expiresIn":3600,"tokenType":"Bearer"}',
          200,
        );
      }
      expect(options.headers['Authorization'], 'Bearer new');
      return ResponseBody.fromString('ok', 200);
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = CallbackAdapter(
      (_) => ResponseBody.fromString('unauthorized', 401),
    );
    dio.interceptors.add(
      AuthInterceptor(tokenStorage: storage, refreshDio: refreshDio),
    );

    final response = await dio.get<String>('/protected');

    expect(response.statusCode, 200);
    expect(storage.value?.accessToken, 'new');
  });

  test('failed refresh clears tokens and expires the session', () async {
    final storage = MemoryTokenStorage(oldSession);
    final refreshDio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    refreshDio.httpClientAdapter = CallbackAdapter(
      (_) => ResponseBody.fromString('unauthorized', 401),
    );
    final interceptor = AuthInterceptor(
      tokenStorage: storage,
      refreshDio: refreshDio,
    );
    var expired = false;
    interceptor.onSessionExpired = () => expired = true;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = CallbackAdapter(
      (_) => ResponseBody.fromString('unauthorized', 401),
    );
    dio.interceptors.add(interceptor);

    await expectLater(
      dio.get<String>('/protected'),
      throwsA(isA<DioException>()),
    );
    expect(storage.value, isNull);
    expect(expired, isTrue);
  });
}
