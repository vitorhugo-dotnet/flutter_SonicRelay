import 'package:dio/dio.dart';

import '../../features/device_identity/data/device_identity_session.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required DeviceIdentitySession deviceIdentitySession,
    required Dio replayDio,
  }) : _deviceIdentitySession = deviceIdentitySession,
       _replayDio = replayDio;

  final DeviceIdentitySession _deviceIdentitySession;
  final Dio _replayDio;

  // Kept temporarily for the legacy auth view model. Device identity failures
  // are handled by the device setup flow and never invoke this callback.
  void Function()? onSessionExpired;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipAuth'] == true) {
      handler.next(options);
      return;
    }

    try {
      final token = await _deviceIdentitySession.accessToken();
      options.headers['Authorization'] = 'DeviceBearer $token';
      handler.next(options);
    } catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
          type: DioExceptionType.unknown,
        ),
      );
    }
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

    try {
      final token = await _deviceIdentitySession.accessToken(
        forceRefresh: true,
      );
      if (!_isReplaySafe(request)) {
        handler.next(err);
        return;
      }
      request.extra['authRetried'] = true;
      request.headers['Authorization'] = 'DeviceBearer $token';
      handler.resolve(await _replayDio.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    } catch (_) {
      handler.next(err);
    }
  }

  bool _isReplaySafe(RequestOptions request) {
    final method = request.method.toUpperCase();
    return method == 'GET' ||
        method == 'HEAD' ||
        request.extra['replaySafe'] == true;
  }
}
