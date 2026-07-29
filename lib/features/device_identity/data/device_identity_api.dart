import 'package:dio/dio.dart';

import 'dto/bootstrap_device_request.dart';
import 'dto/bootstrap_device_response.dart';
import 'dto/device_token_request.dart';
import 'dto/device_token_response.dart';

abstract interface class DeviceIdentityApi {
  Future<BootstrapDeviceResponse> bootstrap(BootstrapDeviceRequest request);

  Future<DeviceTokenResponse> token(DeviceTokenRequest request);
}

class DioDeviceIdentityApi implements DeviceIdentityApi {
  const DioDeviceIdentityApi(this._dio);

  final Dio _dio;

  @override
  Future<BootstrapDeviceResponse> bootstrap(
    BootstrapDeviceRequest request,
  ) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/api/devices/bootstrap',
      data: request.toJson(),
      options: Options(extra: const {'skipAuth': true}),
    );
    return BootstrapDeviceResponse.fromJson(response.data!);
  }

  @override
  Future<DeviceTokenResponse> token(DeviceTokenRequest request) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/api/devices/token',
      data: request.toJson(),
      options: Options(extra: const {'skipAuth': true}),
    );
    return DeviceTokenResponse.fromJson(response.data!);
  }
}
