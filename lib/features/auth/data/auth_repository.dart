import 'package:dio/dio.dart';

import '../../../core/storage/secure_token_storage.dart';
import '../domain/auth_session.dart';
import 'auth_api.dart';
import 'dto/login_request.dart';
import 'dto/refresh_token_request.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
}

class AuthRepository {
  const AuthRepository({
    required AuthApi api,
    required TokenStorage tokenStorage,
  }) : _api = api,
       _tokenStorage = tokenStorage;

  final AuthApi _api;
  final TokenStorage _tokenStorage;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      var session = (await _api.login(
        LoginRequest(email: email, password: password),
      )).toSession();
      await _tokenStorage.write(session);
      final user = await _api.me();
      session = session.copyWith(user: user);
      return session;
    } on DioException catch (error) {
      if (error.response?.statusCode == 400 ||
          error.response?.statusCode == 401) {
        throw const AuthFailure('Email or password is incorrect.');
      }
      throw const AuthFailure(
        'Unable to connect. Check your connection and try again.',
      );
    }
  }

  Future<AuthSession?> restore() async {
    final stored = await _tokenStorage.read();
    if (stored == null) return null;
    try {
      return stored.copyWith(user: await _api.me());
    } catch (_) {
      try {
        return await refresh();
      } catch (_) {
        await _tokenStorage.clear();
        return null;
      }
    }
  }

  Future<AuthSession> refresh() async {
    final stored = await _tokenStorage.read();
    if (stored == null) throw const AuthFailure('Your session has expired.');
    final session = (await _api.refresh(
      RefreshTokenRequest(refreshToken: stored.refreshToken),
    )).toSession();
    await _tokenStorage.write(session);
    return session;
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // Local credentials must always be removed, including while offline.
    } finally {
      await _tokenStorage.clear();
    }
  }
}
