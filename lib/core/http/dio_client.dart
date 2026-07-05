import 'package:dio/dio.dart';

import '../../app/env/app_config.dart';
import 'auth_interceptor.dart';

Dio createDioClient(AppConfig config, AuthInterceptor authInterceptor) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  dio.interceptors.add(authInterceptor);
  return dio;
}

Dio createRefreshDio(AppConfig config) => Dio(
  BaseOptions(
    baseUrl: config.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ),
);
