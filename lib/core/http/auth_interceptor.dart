import 'dart:async';

import 'package:dio/dio.dart';

import '../../features/auth/data/dto/login_response.dart';
import '../../features/auth/domain/auth_session.dart';
import '../storage/secure_token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({required TokenStorage tokenStorage, required Dio refreshDio})
    : _tokenStorage = tokenStorage,
      _refreshDio = refreshDio;

  final TokenStorage _tokenStorage;
  final Dio _refreshDio;
  Future<AuthSession?>? _refreshing;
  void Function()? onSessionExpired;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipAuth'] != true) {
      final session = await _tokenStorage.read();
      if (session != null) {
        options.headers['Authorization'] =
            '${session.tokenType} ${session.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        request.extra['skipAuth'] == true ||
        request.extra['authRetried'] == true) {
      handler.next(err);
      return;
    }

    final session = await _refreshOnce();
    if (session == null) {
      handler.next(err);
      return;
    }

    request.extra['authRetried'] = true;
    request.headers['Authorization'] =
        '${session.tokenType} ${session.accessToken}';
    try {
      handler.resolve(await _refreshDio.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<AuthSession?> _refreshOnce() {
    final pending = _refreshing;
    if (pending != null) return pending;
    final future = _refresh();
    _refreshing = future;
    return future.whenComplete(() => _refreshing = null);
  }

  Future<AuthSession?> _refresh() async {
    final current = await _tokenStorage.read();
    if (current == null) return null;
    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': current.refreshToken},
      );
      final session = LoginResponse.fromJson(response.data!).toSession();
      await _tokenStorage.write(session);
      return session;
    } catch (_) {
      await _tokenStorage.clear();
      onSessionExpired?.call();
      return null;
    }
  }
}
