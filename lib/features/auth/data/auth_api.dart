import 'package:dio/dio.dart';

import '../domain/auth_user.dart';
import 'dto/login_request.dart';
import 'dto/login_response.dart';
import 'dto/refresh_token_request.dart';

abstract interface class AuthApi {
  Future<LoginResponse> login(LoginRequest request);
  Future<LoginResponse> refresh(RefreshTokenRequest request);
  Future<void> logout();
  Future<AuthUser> me();
}

class DioAuthApi implements AuthApi {
  const DioAuthApi(this._dio);
  final Dio _dio;

  @override
  Future<LoginResponse> login(LoginRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: request.toJson(),
      queryParameters: const {'useCookies': false},
      options: Options(extra: const {'skipAuth': true}),
    );
    return LoginResponse.fromJson(response.data!);
  }

  @override
  Future<LoginResponse> refresh(RefreshTokenRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: request.toJson(),
      options: Options(extra: const {'skipAuth': true}),
    );
    return LoginResponse.fromJson(response.data!);
  }

  @override
  Future<void> logout() => _dio.post<void>('/auth/logout');

  @override
  Future<AuthUser> me() async {
    final response = await _dio.get<Map<String, dynamic>>('/auth/me');
    return AuthUser.fromJson(response.data!);
  }
}
