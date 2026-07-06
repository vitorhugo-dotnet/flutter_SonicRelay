import 'package:dio/dio.dart';

import 'dto/device_response.dart';
import 'dto/register_device_request.dart';

abstract interface class DevicesApi {
  Future<DeviceResponse> register(RegisterDeviceRequest request);
  Future<List<DeviceResponse>> list();
  Future<DeviceResponse?> get(String deviceId);
}

class DioDevicesApi implements DevicesApi {
  const DioDevicesApi(this._dio);

  final Dio _dio;

  @override
  Future<DeviceResponse> register(RegisterDeviceRequest request) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/api/devices',
      data: request.toJson(),
    );
    return DeviceResponse.fromJson(response.data!);
  }

  @override
  Future<List<DeviceResponse>> list() async {
    final response = await _dio.get<List<Object?>>('/api/devices');
    return response.data!
        .cast<Map<String, Object?>>()
        .map(DeviceResponse.fromJson)
        .toList(growable: false);
  }

  @override
  Future<DeviceResponse?> get(String deviceId) async {
    try {
      final response = await _dio.get<Map<String, Object?>>(
        '/api/devices/$deviceId',
      );
      return DeviceResponse.fromJson(response.data!);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
